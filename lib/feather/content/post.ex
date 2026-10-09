defmodule Feather.Content.Post do
  @moduledoc """
  A dated entry, listed chronologically. Visible on the site when it has a
  published version and its `publish_at` has passed. Posts without a slug
  are exported under `posts/<public_id>/`.

  Whether a post is a draft is `Feather.Content.draft?/1`.
  """
  use Feather.Schema

  alias Feather.Content.{BlocksType, Slug, Tags}

  @type t :: %__MODULE__{}

  schema "posts" do
    field :public_id, :string
    field :title, :string
    field :slug, :string
    field :emoji, :string
    field :tags, :string
    field :content, BlocksType, default: []
    field :lock_version, :integer, default: 1
    field :publish_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
    belongs_to :published_version, Feather.Content.PostVersion
    has_many :images, Feather.Media.Image
    has_one :book, Feather.Books.Book

    timestamps()
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title,
      :slug,
      :emoji,
      :tags,
      :content,
      :publish_at,
      :header_image_id,
      :thumbnail_image_id
    ])
    |> Feather.Validations.trim_to_nil(:emoji)
    |> Slug.cast_slug()
    |> Tags.cast_tags()
    |> Feather.Validations.validate_emoji(:emoji)
    |> put_default_publish_at()
    |> unsafe_validate_unique([:site_id, :slug], Feather.Repo,
      error_key: :slug,
      message: "has already been taken"
    )
    |> unique_constraint([:site_id, :slug], error_key: :slug, message: "has already been taken")
  end

  @doc false
  def create_changeset(post, attrs) do
    post
    |> changeset(attrs)
    |> Feather.PublicId.put_new()
  end

  defp put_default_publish_at(changeset) do
    case get_field(changeset, :publish_at) do
      nil -> put_change(changeset, :publish_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
