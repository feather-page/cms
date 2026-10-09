defmodule Feather.Content.PostVersion do
  @moduledoc """
  A published state of a post, see `Feather.Content.publish/2`.
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
    :publish_at,
    :header_image_id,
    :thumbnail_image_id
  ]

  schema "post_versions" do
    field :number, :integer
    field :published_at, :utc_datetime_usec
    field :title, :string
    field :slug, :string
    field :emoji, :string
    field :tags, :string
    field :content, BlocksType, default: []
    field :publish_at, :utc_datetime_usec

    belongs_to :post, Feather.Content.Post
    belongs_to :published_by, Feather.Accounts.User
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
  end

  @doc "The post's fields a version copies."
  def copied_fields, do: @copied_fields
end
