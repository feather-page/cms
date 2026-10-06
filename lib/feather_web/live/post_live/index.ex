defmodule FeatherWeb.PostLive.Index do
  @moduledoc """
  The posts of a site, newest first, 20 per page (`?page=`). Each row shows
  the thumbnail, emoji or an icon, the title (or an excerpt for short
  posts), the date, draft/published, a marker for book reviews and the
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
      preview_path={@site_preview_path}
      active={:posts}
    >
      <.header>
        Posts
        <:actions>
          <.button variant="primary" navigate={~p"/sites/#{@site.public_id}/posts/new"} id="new-post">
            <.icon name="plus" size={16} /> New Post
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@pagination.total_entries == 0}
        id="no-posts"
        emoji="✏️"
        message="No posts yet"
        subtitle="Write your first post and share it with the world."
        action_label="New Post"
        action_navigate={~p"/sites/#{@site.public_id}/posts/new"}
      />

      <div id="posts" phx-update="stream" class="list-rows">
        <div :for={{dom_id, post} <- @streams.posts} id={dom_id} class="list-row">
          <.link navigate={edit_path(@site, post)} class="list-row__link">
            <div class="list-row__icon">
              <%= cond do %>
                <% post.thumbnail_image -> %>
                  <img
                    src={image_path(@site, post.thumbnail_image, "mobile_x1.webp")}
                    class="list-row__thumbnail"
                    alt=""
                  />
                <% post.emoji -> %>
                  <span>{post.emoji}</span>
                <% short?(post) -> %>
                  <.icon name="message-square-text" />
                <% true -> %>
                  <.icon name="file-text" />
              <% end %>
            </div>
            <div class="list-row__content">
              <div class={["list-row__title", short?(post) && "list-row__title--short"]}>
                {display_text(post)}
              </div>
              <div class="list-row__meta">
                <span>{format_date(post.publish_at)}</span>
                <span :if={post.draft} class="badge list-row__badge--draft">Draft</span>
                <span :if={!post.draft} class="badge list-row__badge--published">Published</span>
                <span :if={post.book} class="badge list-row__badge--review" title="Book review">
                  <.icon name="book-open" size={12} /> Review: {post.book.title}
                  <span :if={post.book.rating}>{stars(post.book.rating)}</span>
                </span>
              </div>
            </div>
            <div :if={Content.tag_list(post) != []} class="list-row__tags">
              <span :for={tag <- Enum.take(Content.tag_list(post), 3)} class="list-row__tag">
                {tag}
              </span>
            </div>
          </.link>
          <div class="list-row__actions">
            <.link
              navigate={edit_path(@site, post)}
              class="btn btn-sm btn-link"
              title="Edit"
              aria-label="Edit"
            >
              <.icon name="pencil" size={16} />
            </.link>
            <button
              type="button"
              id={"delete-post-#{post.public_id}"}
              class="btn btn-sm btn-link text-danger"
              title="Delete"
              aria-label="Delete"
              phx-click="delete"
              phx-value-id={post.public_id}
              data-confirm="Are you sure?"
            >
              <.icon name="trash" size={16} />
            </button>
          </div>
        </div>
      </div>

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
    post = Content.get_post!(scope, id)
    {:ok, _post} = Content.delete_post(scope, post)

    {:noreply,
     socket
     |> put_flash(:info, "Post was successfully deleted.")
     |> load_posts(socket.assigns.pagination.page)}
  end

  defp load_posts(socket, page) do
    pagination = Content.paginate_posts(socket.assigns.current_scope, page)

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
