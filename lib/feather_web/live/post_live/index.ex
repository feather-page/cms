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
      preview_path={@site_preview_path}
      active={:posts}
    >
      <.header>
        Posts
        <:actions>
          <.button variant="primary" navigate={~p"/sites/#{@site.public_id}/posts/new"} id="new-post">
            <.icon name="plus" size={16} /> New post
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@pagination.total_entries == 0}
        id="no-posts"
        emoji="✏️"
        message="No posts yet"
        subtitle="Write your first post and share it with the world."
      />

      <.list_card id="posts" stream hidden={@pagination.total_entries == 0}>
        <.list_row
          :for={{dom_id, post} <- @streams.posts}
          id={dom_id}
          navigate={edit_path(@site, post)}
          excerpt={short?(post)}
        >
          <:leading>
            <%= cond do %>
              <% post.thumbnail_image -> %>
                <img src={image_path(@site, post.thumbnail_image, "mobile_x1.webp")} alt="" />
              <% post.emoji -> %>
                {post.emoji}
              <% short?(post) -> %>
                <.icon name="message-square-text" />
              <% true -> %>
                <.icon name="file-text" />
            <% end %>
          </:leading>
          {display_text(post)}
          <:meta>
            <span class="list-row__date">{format_date(post.publish_at)}</span>
            <.publication_badge status={Content.publication_status(post)} />
            <span :if={post.book} class="list-row__review" title="Book review">
              <span :if={post.book.rating} class="text-warning">{stars(post.book.rating)} ·</span>
              {post.book.title}
            </span>
            <span :if={Content.tag_list(post) != []} class="list-row__tags d-none d-md-inline">
              <span :for={tag <- Enum.take(Content.tag_list(post), 3)} class="list-row__tag">
                #{tag}
              </span>
            </span>
          </:meta>
          <:action
            id={"delete-post-#{post.public_id}"}
            icon="trash"
            label="Delete"
            click={JS.push("delete", value: %{id: post.public_id})}
            confirm="Are you sure?"
            danger
          />
        </.list_row>
      </.list_card>

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
