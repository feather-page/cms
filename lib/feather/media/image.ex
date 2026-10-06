defmodule Feather.Media.Image do
  @moduledoc """
  An uploaded or fetched image of a site.

  The files live in the storage root, see `Feather.Media`. `post_id`,
  `page_id` and `project_id` record which record embeds the image in its
  content; header, thumbnail and cover images are referenced by their
  owner instead.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "images" do
    field :public_id, :string
    field :filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :width, :integer
    field :height, :integer
    field :source_url, :string
    field :unsplash_data, :map

    belongs_to :site, Feather.Sites.Site
    belongs_to :post, Feather.Content.Post
    belongs_to :page, Feather.Content.Page
    belongs_to :project, Feather.Content.Project

    timestamps()
  end

  @doc false
  def create_changeset(image, attrs) do
    image
    |> cast(attrs, [
      :public_id,
      :filename,
      :content_type,
      :byte_size,
      :width,
      :height,
      :source_url,
      :unsplash_data,
      :post_id,
      :page_id,
      :project_id
    ])
    |> Feather.PublicId.put_new()
    |> validate_required([:public_id, :filename, :content_type, :byte_size])
    |> validate_number(:byte_size,
      less_than_or_equal_to: Feather.Media.max_byte_size(),
      message: "is too big (at most 25 MB)"
    )
    |> unique_constraint(:public_id)
  end

  @doc "Returns true if the image came from Unsplash."
  @spec unsplash?(t()) :: boolean()
  def unsplash?(%__MODULE__{unsplash_data: data}), do: is_map(data) and map_size(data) > 0

  @doc "The Unsplash photographer's name, or nil."
  def unsplash_photographer_name(%__MODULE__{unsplash_data: data}),
    do: unsplash(data, "photographer_name")

  @doc "The Unsplash photographer's profile URL, or nil."
  def unsplash_photographer_url(%__MODULE__{unsplash_data: data}),
    do: unsplash(data, "photographer_url")

  @doc "The Unsplash download location to ping when the photo is used, or nil."
  def unsplash_download_location(%__MODULE__{unsplash_data: data}),
    do: unsplash(data, "download_location")

  defp unsplash(%{} = data, key), do: Map.get(data, key)
  defp unsplash(_data, _key), do: nil
end
