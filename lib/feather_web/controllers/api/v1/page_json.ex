defmodule FeatherWeb.Api.V1.PageJSON do
  @moduledoc """
  JSON of pages in the content API (`PageResponse` in `docs/api/openapi.yml`).
  Expects header and thumbnail images to be preloaded.
  """

  alias Feather.Content
  alias Feather.Content.{Page, Tags}
  alias FeatherWeb.Api.V1.{ApiJSON, Pagination}

  def index(%{page: page}) do
    %{data: Enum.map(page.entries, &data/1), meta: Pagination.meta(page)}
  end

  def show(%{page: page}), do: %{data: data(page)}

  defp data(%Page{} = page) do
    %{
      id: page.public_id,
      title: page.title,
      slug: page.slug,
      emoji: page.emoji,
      page_type: page.page_type,
      draft: Content.draft?(page),
      tags: Tags.tag_list(page),
      content: ApiJSON.content(page.content),
      header_image_id: ApiJSON.image_id(page.header_image),
      thumbnail_image_id: ApiJSON.image_id(page.thumbnail_image),
      created_at: ApiJSON.timestamp(page.inserted_at),
      updated_at: ApiJSON.timestamp(page.updated_at)
    }
  end
end
