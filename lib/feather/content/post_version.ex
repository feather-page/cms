defmodule Feather.Content.PostVersion do
  @moduledoc """
  A published state of a post, see `Feather.Content.publish/2`.

  `embedding` and `embedding_model` hold what the embedding model read in
  it (`Feather.Content.Embedding`); they are not copied from the post.
  """
  use Feather.Schema

  alias Feather.Content.BlocksType

  @type t :: %__MODULE__{}

  @copied_fields [
    :title,
    :slug,
    :description,
    :description_generated,
    :meta_title,
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
    field :description, :string
    field :description_generated, :boolean, default: false
    field :meta_title, :string
    field :embedding, :binary
    field :embedding_model, :string

    belongs_to :post, Feather.Content.Post
    belongs_to :published_by, Feather.Accounts.User
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
  end

  @doc "The post's fields a version copies."
  def copied_fields, do: @copied_fields
end
