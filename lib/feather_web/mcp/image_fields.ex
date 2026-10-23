defmodule FeatherWeb.MCP.ImageFields do
  @moduledoc """
  What the image tools share: finding an image, an image as a tool result
  and why an image could not be added from a URL.
  """

  alias Feather.Accounts.Scope
  alias Feather.Media
  alias Feather.Media.Image
  alias FeatherWeb.MCP.Tool

  @doc "The image of the site with the public id `id`."
  @spec fetch_image(Scope.t(), String.t()) :: {:ok, Image.t()} | {:error, String.t()}
  def fetch_image(%Scope{} = scope, id) do
    case Media.get_image(scope, id) do
      nil ->
        {:error, "There is no image #{id} on #{scope.site.domain}. list_images lists its images."}

      image ->
        {:ok, image}
    end
  end

  @doc """
  An image as a tool result: `id` (its public id, which posts and pages
  use), its file name, alternative text, size in pixels and the URL it was
  added from.
  """
  @spec result(Image.t()) :: map()
  def result(%Image{} = image) do
    %{
      id: image.public_id,
      filename: image.filename,
      alt: image.alt,
      width: image.width,
      height: image.height,
      source_url: image.source_url
    }
  end

  @doc "Why `Feather.Media.create_image_from_url/4` added no image, as a message."
  @spec download_error(Ecto.Changeset.t() | String.t()) :: String.t()
  def download_error(%Ecto.Changeset{} = changeset), do: Tool.errors(changeset)
  def download_error(message) when is_binary(message), do: message
end
