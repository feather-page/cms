defmodule Feather.Content.Post do
  @moduledoc """
  A dated entry, listed chronologically. Published when it is not a draft
  and `publish_at` has passed. Posts without a slug are exported under
  `posts/<public_id>/`.
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
    field :draft, :boolean, default: false
    field :publish_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
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
      :draft,
      :publish_at,
      :header_image_id,
      :thumbnail_image_id
    ])
    |> Feather.Validations.trim_to_nil(:emoji)
    |> Slug.cast_slug()
    |> Tags.cast_tags()
    |> Feather.Validations.validate_emoji(:emoji)
    |> put_default_publish_at()
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

  @doc """
  Returns true if the post is visible on the site: not a draft and its
  `publish_at` is not in the future.
  """
  @spec published?(t(), DateTime.t()) :: boolean()
  def published?(%__MODULE__{} = post, now \\ DateTime.utc_now()) do
    not post.draft and not is_nil(post.publish_at) and
      DateTime.compare(post.publish_at, now) != :gt
  end
end
