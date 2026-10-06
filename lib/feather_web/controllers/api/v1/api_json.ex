defmodule FeatherWeb.Api.V1.ApiJSON do
  @moduledoc """
  Value formats shared by the content API's JSON views.
  """

  alias Feather.Media.Image

  @doc "An ISO 8601 timestamp in UTC with second precision, or nil."
  @spec timestamp(DateTime.t() | nil) :: String.t() | nil
  def timestamp(nil), do: nil

  def timestamp(%DateTime{} = datetime),
    do: datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  @doc """
  Content blocks as the API shows them: fields without a value (nil) are
  left out, as the block schemas have no null fields (except the optional
  embed `width` and `height`).
  """
  @spec content([map()] | nil) :: [map()]
  def content(nil), do: []

  def content(blocks) when is_list(blocks) do
    Enum.map(blocks, fn block -> Map.reject(block, fn {_key, value} -> is_nil(value) end) end)
  end

  @doc "The public id of a (preloaded) image, or nil."
  @spec image_id(Image.t() | nil) :: String.t() | nil
  def image_id(%Image{public_id: public_id}), do: public_id
  def image_id(_image), do: nil
end
