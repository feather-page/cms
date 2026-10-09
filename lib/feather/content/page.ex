defmodule Feather.Content.Page do
  @moduledoc """
  An undated page at a fixed URL. Its `page_type` decides whether it shows
  free content (`default`), the book catalogue (`books`) or the project
  list (`projects`). The page with slug `/` is the homepage.

  `add_to_navigation` is a virtual field: `Feather.Content` fills it when
  loading a page and adds or removes the page from the main navigation when
  it is given on save.
  """
  use Feather.Schema

  alias Feather.Content.{BlocksType, Slug, Tags}

  @type t :: %__MODULE__{}

  @page_types ~w(default books projects)

  schema "pages" do
    field :public_id, :string
    field :title, :string
    field :slug, :string
    field :emoji, :string
    field :tags, :string
    field :content, BlocksType, default: []
    field :lock_version, :integer, default: 1
    field :page_type, :string, default: "default"
    field :add_to_navigation, :boolean, virtual: true, default: false

    belongs_to :site, Feather.Sites.Site
    belongs_to :header_image, Feather.Media.Image
    belongs_to :thumbnail_image, Feather.Media.Image
    belongs_to :published_version, Feather.Content.PageVersion
    has_many :images, Feather.Media.Image
    has_many :navigation_items, Feather.Sites.NavigationItem

    timestamps()
  end

  @doc "The valid page types."
  def page_types, do: @page_types

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [
      :title,
      :slug,
      :emoji,
      :tags,
      :content,
      :page_type,
      :add_to_navigation,
      :header_image_id,
      :thumbnail_image_id
    ])
    |> Feather.Validations.trim_to_nil(:emoji)
    # Any page may claim "/", the unique index on (site_id, slug) makes sure
    # only one does: that page is the homepage.
    |> Slug.cast_slug(required: true, allow_root: true)
    |> Tags.cast_tags()
    |> validate_required([:page_type])
    |> validate_inclusion(:page_type, @page_types)
    |> Feather.Validations.validate_emoji(:emoji)
    |> unsafe_validate_unique([:site_id, :slug], Feather.Repo,
      error_key: :slug,
      message: "has already been taken"
    )
    |> unique_constraint([:site_id, :slug], error_key: :slug, message: "has already been taken")
  end

  @doc false
  def create_changeset(page, attrs) do
    page
    |> changeset(attrs)
    |> Feather.PublicId.put_new()
  end

  @doc "Returns true for the homepage (slug `/`)."
  @spec homepage?(t()) :: boolean()
  def homepage?(%__MODULE__{slug: slug}), do: slug == "/"
end
