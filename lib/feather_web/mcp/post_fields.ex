defmodule FeatherWeb.MCP.PostFields do
  @moduledoc """
  The fields of a post in the post tools, those of the post form: their
  input schema, the attributes they set and a post as a tool result.
  """

  use FeatherWeb, :verified_routes

  alias Feather.Accounts.Scope
  alias Feather.Content
  alias Feather.Content.Post
  alias Feather.Validations
  alias FeatherWeb.MCP.ContentFields

  @fields ~w(title slug meta_title description emoji tags publish_at header_image
             thumbnail_image content)

  @doc "The input schema properties of the post's fields."
  @spec properties() :: map()
  def properties do
    %{
      "title" => %{"type" => ["string", "null"], "description" => "None for a short post"},
      "slug" => %{
        "type" => ["string", "null"],
        "description" => "The post's path on the site, such as /my-first-post"
      },
      "meta_title" => %{
        "type" => ["string", "null"],
        "description" =>
          "Names a short post in the browser tab, link previews and feeds, not on the site"
      },
      "description" => %{
        "type" => ["string", "null"],
        "description" => "One sentence for search results and link previews"
      },
      "emoji" => %{"type" => ["string", "null"], "description" => "An emoji for the post"},
      "tags" => %{"type" => ["array", "null"], "items" => %{"type" => "string"}},
      "publish_at" => %{
        "type" => "string",
        "format" => "date-time",
        "description" =>
          "The post's date and time in UTC, such as 2026-10-23T09:00:00Z; now by default. " <>
            "A time in the future makes the published post a scheduled one."
      },
      "header_image" =>
        ContentFields.image_property("The id of the site's image shown large above the post"),
      "thumbnail_image" =>
        ContentFields.image_property("The id of the site's image shown with the post in lists"),
      "content" => ContentFields.content_property()
    }
  end

  @doc """
  The post's attributes among the arguments, with content, images and tags
  as `Feather.Content` takes them.
  """
  @spec attrs(Scope.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def attrs(%Scope{} = scope, arguments) do
    with {:ok, attrs} <- ContentFields.cast(scope, Map.take(arguments, @fields)) do
      {:ok, Map.replace_lazy(attrs, "tags", &join_tags/1)}
    end
  end

  defp join_tags(nil), do: nil
  defp join_tags(tags), do: Enum.join(tags, ", ")

  @doc "The post of the site with the public id `id`."
  @spec fetch_post(Scope.t(), String.t()) :: {:ok, Post.t()} | {:error, String.t()}
  def fetch_post(%Scope{} = scope, id) do
    case Content.get_post(scope, id) do
      nil ->
        {:error, "There is no post #{id} on #{scope.site.domain}. list_posts lists its posts."}

      post ->
        {:ok, post}
    end
  end

  @doc """
  A post as a tool result: its fields, `id` (its public id), `book` (the id
  of the book it reviews), its publication `status`, the `lock_version` an
  update builds on and the links to the editor and, once it has a slug, the
  preview.
  """
  @spec result(Scope.t(), Post.t()) :: map()
  def result(%Scope{} = scope, %Post{} = post) do
    post = Content.preload_post_details(post)

    %{
      id: post.public_id,
      title: post.title,
      slug: post.slug,
      meta_title: post.meta_title,
      description: post.description,
      emoji: post.emoji,
      tags: Content.tag_list(post),
      publish_at: post.publish_at,
      header_image: ContentFields.public_id(post.header_image),
      thumbnail_image: ContentFields.public_id(post.thumbnail_image),
      content: ContentFields.content(post),
      book: ContentFields.public_id(post.book),
      status: Content.publication_status(post),
      lock_version: post.lock_version,
      editor_url: url(~p"/sites/#{scope.site.public_id}/posts/#{post.public_id}/edit"),
      preview_url: ContentFields.preview_url(scope, post)
    }
  end

  @doc """
  A post as an entry of a list; `excerpt` is the start of a short post's
  text. Expects `Feather.Content.preload_post_details/1`.
  """
  @spec summary(Post.t()) :: map()
  def summary(%Post{} = post) do
    %{
      id: post.public_id,
      title: post.title,
      excerpt: if(Validations.blank?(post.title), do: Content.content_excerpt(post, 120)),
      slug: post.slug,
      publish_at: post.publish_at,
      status: Content.publication_status(post),
      book: ContentFields.public_id(post.book)
    }
  end
end
