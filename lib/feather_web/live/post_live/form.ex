defmodule FeatherWeb.PostLive.Form do
  @moduledoc """
  Creates and edits posts: header image picker, title and slug (hidden for
  short posts, slug suggested from the title), tags, Editor.js content,
  publish date and draft flag.
  """
  use FeatherWeb, :live_view

  import FeatherWeb.ContentFormComponents

  alias Feather.Content
  alias Feather.Content.Post
  alias FeatherWeb.{ContentForm, HeaderImagePicker}

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      preview_path={@site_preview_path}
      active={:posts}
    >
      <.header back={~p"/sites/#{@site.public_id}/posts"} back_label="Posts" truncate>
        {@page_title}
        <:badge :if={@live_action == :edit}>
          <.status_badge :if={@post.draft} kind={:draft}>Draft</.status_badge>
          <.status_badge :if={!@post.draft} kind={:published}>Published</.status_badge>
        </:badge>
      </.header>

      <.editor_layout id="post" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form for={@form} id="post-form" phx-change="validate" phx-submit="save">
            <.header_image_fields form={@form} />
            <.title_field field={@form[:title]} hidden={!@show_title_and_slug?} />
            <.editor
              id="post-content-editor"
              field={@form[:content]}
              value={@editor_json}
              site={@site}
            >
              <.content_length length={@content_length} />
            </.editor>
          </.form>
        </:main>
        <:details>
          <.slug_field field={@form[:slug]} form="post-form" hidden={!@show_title_and_slug?} />
          <.input
            field={@form[:tags]}
            label="Tags"
            help="Comma-separated, e.g. ruby, rails, web"
            form="post-form"
            phx-debounce="300"
          />
          <.input
            field={@form[:publish_at]}
            type="datetime-local"
            label="Publish at (UTC)"
            step="60"
            form="post-form"
          />
          <.input field={@form[:draft]} type="checkbox" label="Draft" switch form="post-form" />
          <.live_component
            module={HeaderImagePicker}
            id="post-header-image-picker"
            current_scope={@current_scope}
            header_image={@header_image}
            thumbnail_image={@thumbnail_image}
            emoji={@form[:emoji].value}
          />
        </:details>
      </.editor_layout>

      <.action_bar sticky>
        <button
          type="submit"
          form="post-form"
          id="save-post"
          class="btn btn-primary"
          phx-disable-with="Saving..."
        >
          {if @live_action == :new, do: "Create post", else: "Save"}
        </button>
        <.link navigate={~p"/sites/#{@site.public_id}/posts"} class="btn btn-light">Cancel</.link>
        <:danger :if={@live_action == :edit}>
          <button
            type="button"
            id="delete-post"
            class="btn btn-outline-danger"
            phx-click="delete"
            data-confirm="Delete this post?"
          >
            <.icon name="trash-2" size={16} /> Delete
          </button>
        </:danger>
      </.action_bar>
    </.site_shell>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    post =
      case socket.assigns.live_action do
        :new -> %Post{site_id: scope.site.id}
        :edit -> scope |> Content.get_post!(params["id"]) |> Content.preload_images()
      end

    {:ok,
     socket
     |> assign(:site, scope.site)
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new,
         do: "New post",
         else: ContentForm.heading(post, "Untitled post")
       )
     )
     |> assign(:post, post)
     |> assign(:header_image, ContentForm.loaded(post.header_image))
     |> assign(:thumbnail_image, ContentForm.loaded(post.thumbnail_image))
     |> assign(:slug_touched?, ContentForm.present?(post.slug))
     |> assign(:editor_json, ContentForm.editor_json(scope, post))
     |> assign_form(%{})}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params} = params, socket) do
    socket =
      assign(
        socket,
        :slug_touched?,
        socket.assigns.slug_touched? or ContentForm.slug_target?(params, "post")
      )

    post_params =
      ContentForm.maybe_suggest_slug(
        post_params,
        params,
        "post",
        socket.assigns.current_scope,
        socket.assigns.slug_touched?
      )

    {:noreply, assign_form(socket, post_params, :validate)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.live_action, post_params)
  end

  def handle_event("delete", _params, socket) do
    {:ok, _post} = Content.delete_post(socket.assigns.current_scope, socket.assigns.post)

    {:noreply,
     socket
     |> put_flash(:info, "Post was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/posts")}
  end

  @impl true
  def handle_info({HeaderImagePicker, change}, socket) do
    params = ContentForm.put_picker_change(socket.assigns.params, change)

    {:noreply,
     socket
     |> assign(ContentForm.picker_assigns(change))
     |> assign_form(params, socket.assigns.form.source.action)}
  end

  defp save_post(socket, :new, post_params) do
    case Content.create_post(socket.assigns.current_scope, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post was successfully created.")
         |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/posts")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, assign_form(socket, post_params, :insert)}
    end
  end

  defp save_post(socket, :edit, post_params) do
    case Content.update_post(socket.assigns.current_scope, socket.assigns.post, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post was successfully updated.")
         |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/posts")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, assign_form(socket, post_params, :update)}
    end
  end

  defp assign_form(socket, params, action \\ nil) do
    %{current_scope: scope, post: post} = socket.assigns

    changeset =
      scope
      |> Content.change_post(post, params)
      |> Map.put(:action, action)

    form = to_form(changeset)
    length = ContentForm.content_length(params, post)

    socket
    |> assign(:params, params)
    |> assign(:form, form)
    |> assign(:content_length, length)
    |> assign(:show_title_and_slug?, ContentForm.show_title_and_slug?(form, length))
  end
end
