defmodule FeatherWeb.Api.V1.PostJSON do
  @moduledoc """
  JSON of posts in the content API (`PostResponse` in `docs/api/openapi.yml`).
  Expects header and thumbnail images to be preloaded.
  """

  alias Feather.Content
  alias Feather.Content.{Post, Tags}
  alias FeatherWeb.Api.V1.{ApiJSON, Pagination}

  def index(%{page: page}) do
    %{data: Enum.map(page.entries, &data/1), meta: Pagination.meta(page)}
  end

  def show(%{post: post}), do: %{data: data(post)}

  defp data(%Post{} = post) do
    %{
      id: post.public_id,
      title: post.title,
      slug: post.slug,
      emoji: post.emoji,
      draft: Content.draft?(post),
      publish_at: ApiJSON.timestamp(post.publish_at),
      tags: Tags.tag_list(post),
      content: ApiJSON.content(post.content),
      header_image_id: ApiJSON.image_id(post.header_image),
      thumbnail_image_id: ApiJSON.image_id(post.thumbnail_image),
      created_at: ApiJSON.timestamp(post.inserted_at),
      updated_at: ApiJSON.timestamp(post.updated_at)
    }
  end
end
