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
      <.header>
        {@page_title}
        <:subtitle>
          <.link navigate={~p"/sites/#{@site.public_id}/posts"}>Posts</.link> / {@page_title}
        </:subtitle>
      </.header>

      <.live_component
        module={HeaderImagePicker}
        id="post-header-image-picker"
        current_scope={@current_scope}
        header_image={@header_image}
        thumbnail_image={@thumbnail_image}
        emoji={@form[:emoji].value}
      />

      <.form for={@form} id="post-form" phx-change="validate" phx-submit="save">
        <.header_image_fields form={@form} />
        <.title_and_slug form={@form} hidden={!@show_title_and_slug?} />
        <.input
          field={@form[:tags]}
          label="Tags"
          help="Comma-separated, e.g. ruby, rails, web"
          phx-debounce="300"
        />
        <.editor id="post-content-editor" field={@form[:content]} value={@editor_json} site={@site}>
          <.content_length length={@content_length} />
        </.editor>
        <.input field={@form[:publish_at]} type="datetime-local" label="Publish at (UTC)" step="60" />
        <.input field={@form[:draft]} type="checkbox" label="Draft" />

        <div class="d-flex gap-2">
          <.button variant="primary" phx-disable-with="Saving..." id="save-post">
            {if @live_action == :new, do: "Create Post", else: "Update Post"}
          </.button>
          <.button navigate={~p"/sites/#{@site.public_id}/posts"}>Cancel</.button>
        </div>
      </.form>
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
       if(socket.assigns.live_action == :new, do: "New Post", else: "Edit Post")
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
