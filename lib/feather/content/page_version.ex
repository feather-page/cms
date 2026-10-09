defmodule Feather.Content.PageVersion do
  @moduledoc """
  A published state of a page, see `Feather.Content.publish/2`. Whether
  the page is in the main navigation is not part of it.
  """
  use Feather.Schema

  alias Feather.Content.BlocksType

  @type t :: %__MODULE__{}

  @copied_fields [
    :title,
    :slug,
    :emoji,
    :tags,
    :content,
    :page_type,
    :header_image_id,
    :thumbnail_image_id
  ]

  schema "page_versions" do
    field :number, :integer
    field :published_at, :utc_datetime_usec
    field :title, :string
    field :slug, :string
    field :emoji, :string
    field :tags, :string
    field :content, BlocksType, default: []
    field :page_type, :string

    belongs_to :page, Feather.Content.Page
    belongs_to :published_by, Feather.Accounts.User
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
  end

  @doc "The page's fields a version copies."
  def copied_fields, do: @copied_fields
end
