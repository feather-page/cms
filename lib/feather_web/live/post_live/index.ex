defmodule FeatherWeb.PostLive.Index do
  @moduledoc """
  The posts of a site, newest first, 20 per page (`?page=`). Each row shows
  the thumbnail, emoji or an icon, the title (or an excerpt for short
  posts), the date, the publication status, the book of a review and the
  first tags.
  """
  use FeatherWeb, :live_view

  alias Feather.Content
  alias Feather.Content.Post

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
      <.header>
        Posts
        <:actions :if={@pagination.total_entries > 0}>
          <.button
            variant={:primary}
            icon="plus"
            navigate={~p"/sites/#{@site.public_id}/posts/new"}
            id="new-post"
          >
            New post
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@pagination.total_entries == 0}
        id="no-posts"
        layout={:page}
        plush_size={:xxl}
        plush="feather"
        title="No posts yet"
      >
        Write your first post and share it with the world.
        <:action>
          <.button navigate={~p"/sites/#{@site.public_id}/posts/new"} variant={:primary} icon="plus">
            Write your first post
          </.button>
        </:action>
      </.empty_state>

      <.list id="posts" phx-update="stream" class={@pagination.total_entries == 0 && "hidden"}>
        <.list_row
          :for={{dom_id, post} <- @streams.posts}
          id={dom_id}
          navigate={edit_path(@site, post)}
          title={display_text(post)}
          actions_label="Actions"
          menu={:always}
          trailing_on_phone={:meta}
        >
          <:leading>
            <.tile
              image={
                post.thumbnail_image && image_path(@site, post.thumbnail_image, "mobile_x1.webp")
              }
              emoji={post.emoji}
              icon={if short?(post), do: "message-square-text", else: "file-text"}
            />
          </:leading>
          <:meta>
            <span>{format_date(post.publish_at)}</span>
            <span :if={post.book} title="Book review">
              · <.rating value={post.book.rating} class="text-warning-content dark:text-warning" />
              {post.book.title}
            </span>
            <span :if={Content.tag_list(post) != []} class="max-md:hidden">
              · {Enum.map_join(Enum.take(Content.tag_list(post), 3), " ", &"##{&1}")}
            </span>
          </:meta>
          <:trailing
            :let={place}
            :if={Content.publication_status(post) != :published}
            class="md:w-44 md:justify-start"
          >
            <.publication_badge
              status={Content.publication_status(post)}
              style={if place == :meta, do: :text, else: :dot}
            />
          </:trailing>
          <:action
            id={"delete-post-#{post.public_id}"}
            icon="trash-2"
            label="Delete"
            on_click={JS.push("delete", value: %{id: post.public_id})}
            confirm={"Delete “#{display_text(post)}”?"}
            confirm_text={delete_text("post", post)}
            danger
          />
        </.list_row>
      </.list>

      <.pagination pagination={@pagination} path={&~p"/sites/#{@site.public_id}/posts?page=#{&1}"} />
    </.site_shell>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:site, socket.assigns.current_scope.site)
     |> assign(:page_title, "Posts")
     |> stream_configure(:posts, dom_id: &"post-#{&1.public_id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_posts(socket, params["page"])}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with %Post{} = post <- Content.get_post(scope, id),
           {:ok, _post} <- Content.delete_post(scope, post) do
        put_flash(socket, :info, "Post was successfully deleted.")
      else
        nil -> put_flash(socket, :error, "This post no longer exists.")
        {:error, _reason} -> put_flash(socket, :error, "The post could not be deleted.")
      end

    {:noreply, load_posts(socket, socket.assigns.pagination.page)}
  end

  defp load_posts(socket, page) do
    pagination = Content.paginate_admin_posts(socket.assigns.current_scope, page)

    socket
    |> assign(:pagination, pagination)
    |> stream(:posts, pagination.entries, reset: true)
  end

  defp edit_path(site, post), do: ~p"/sites/#{site.public_id}/posts/#{post.public_id}/edit"

  defp short?(%Post{title: title}), do: not FeatherWeb.ContentForm.present?(title)

  defp display_text(post) do
    if short?(post) do
      case Content.content_excerpt(post, 120) do
        "" -> "(empty post)"
        excerpt -> excerpt
      end
    else
      post.title
    end
  end

  defp format_date(nil), do: ""
  defp format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d/%m/%Y")
end
