defmodule FeatherWeb.Api.V1.ImageJSON do
  @moduledoc """
  JSON of images in the content API (`ImageResponse` in
  `docs/api/openapi.yml`).
  """

  alias Feather.Media.Image
  alias FeatherWeb.Api.V1.ApiJSON

  def show(%{image: %Image{} = image}) do
    %{
      data: %{
        id: image.public_id,
        source_url: image.source_url,
        created_at: ApiJSON.timestamp(image.inserted_at),
        updated_at: ApiJSON.timestamp(image.updated_at)
      }
    }
  end
end
