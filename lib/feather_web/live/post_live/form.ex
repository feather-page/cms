defmodule FeatherWeb.PostLive.Form do
  @moduledoc """
  Creates and edits posts: header image picker, title and slug (hidden for
  short posts, slug suggested from the title), tags, block content and
  publish date. Every change is saved into the unpublished changes at
  once, the first input creates the post as a draft (see "Autosave" in
  `FeatherWeb.ContentForm`). Publish publishes them; Discard puts the
  published version back; Restore puts an earlier version into the
  unpublished changes; Unpublish makes the post a draft.
  """
  @behaviour FeatherWeb.ContentForm

  use FeatherWeb, :live_view

  import FeatherWeb.ContentFormComponents

  alias Feather.{Content, Publishing}
  alias Feather.Content.Post
  alias FeatherWeb.{ContentForm, HeaderImagePicker}

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      active={:posts}
    >
      <:bar>
        <.breadcrumbs label="Breadcrumb">
          <:crumb navigate={~p"/sites/#{@site.public_id}/posts"}>Posts</:crumb>
          <:crumb>{@page_title}</:crumb>
        </.breadcrumbs>
        <.publication_badge
          :if={@live_action == :edit}
          id="status-badge"
          status={@publication_status}
          live={Publishing.live?(@site_deploy.targets, @published_version)}
        />
      </:bar>
      <:bar_actions>
        <div id="publish-actions" class="flex items-center gap-3">
          <.editor_status editor="post-content-editor" />
          <div class="max-md:hidden">
            <.content_actions
              id="post"
              noun="post"
              record={@post}
              form={@form}
              status={@publication_status}
              changed_elsewhere?={@changed_elsewhere?}
            />
          </div>
        </div>
      </:bar_actions>

      <.editor_layout id="post" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form
            for={@form}
            id="post-form"
            phx-change="autosave"
            phx-submit="autosave"
            phx-auto-recover="recover"
          >
            <.lock_version_field record={@post} />
            <.header_image_fields form={@form} />
            <.title_field field={@form[:title]} hidden={!@show_title_and_slug?} />
            <.editor
              id="post-content-editor"
              site={@current_scope.site}
              value={@editor_json}
              record={@post}
              status={ContentForm.autosave_status(@form, @changed_elsewhere?)}
            >
              <.content_length
                :if={ContentForm.untitled?(@form)}
                length={@content_length}
              />
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
          <.live_component
            module={HeaderImagePicker}
            id="post-header-image-picker"
            current_scope={@current_scope}
            header_image={@header_image}
            thumbnail_image={@thumbnail_image}
            emoji={@form[:emoji].value}
          />
          <.record_versions versions={@versions} record={@post} />
        </:details>
      </.editor_layout>

      <.action_bar
        sticky
        id="action-bar"
        class="mt-6 items-center md:hidden [&_.join]:flex-1 [&_.join>.btn]:flex-1"
      >
        <.editor_status
          editor="post-content-editor"
          place={:bottom}
        />
        <.content_actions
          id="post"
          noun="post"
          record={@post}
          form={@form}
          status={@publication_status}
          changed_elsewhere?={@changed_elsewhere?}
          place={:bottom}
        />
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

    {:ok, ContentForm.mount_record(socket, post)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    page_title =
      case socket.assigns.live_action do
        :new -> "New post"
        :edit -> ContentForm.heading(socket.assigns.post, "Untitled post")
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    %{current_scope: scope, post: post} = socket.assigns

    socket =
      with %Post{} = post <- Content.get_post(scope, post.public_id),
           {:ok, _post} <- Content.delete_post(scope, post) do
        put_flash(socket, :info, "Post was successfully deleted.")
      else
        nil -> put_flash(socket, :error, "This post no longer exists.")
        {:error, _reason} -> put_flash(socket, :error, "The post could not be deleted.")
      end

    {:noreply, push_navigate(socket, to: ~p"/sites/#{socket.assigns.site.public_id}/posts")}
  end

  def handle_event(event, params, socket), do: ContentForm.handle_event(event, params, socket)

  @impl true
  def handle_info(message, socket), do: ContentForm.handle_info(message, socket)

  @impl ContentForm
  def record(socket), do: socket.assigns.post

  @impl ContentForm
  def save_fields(socket, attrs, opts) do
    %{current_scope: scope, post: post} = socket.assigns

    with {:ok, post} <- Content.autosave(scope, post, attrs, opts), do: {:ok, post, socket}
  end

  @impl ContentForm
  def edit_path(socket, post),
    do: ~p"/sites/#{socket.assigns.site.public_id}/posts/#{post.public_id}/edit"

  @impl ContentForm
  def assign_record(socket, post), do: assign(socket, :post, post)

  @impl ContentForm
  def noun, do: "Post"

  @impl ContentForm
  def assign_form(socket, params, action \\ nil) do
    %{current_scope: scope, post: post} = socket.assigns

    changeset =
      scope
      |> Content.change_post(post, params)
      |> Map.put(:action, action)

    form = to_form(changeset)
    length = ContentForm.content_length(post)

    socket
    |> assign(:params, params)
    |> assign(:form, form)
    |> assign(:content_length, length)
    |> assign(:show_title_and_slug?, ContentForm.show_title_and_slug?(form, length))
  end
end
