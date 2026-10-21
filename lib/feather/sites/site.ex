defmodule Feather.Sites.Site do
  @moduledoc """
  A managed website with its own domain; the container for all content.

  After each deploy the CMS tells IndexNow and, with the site's
  `archive_org_keys`, archive.org what changed (ADR 0027). The keys are
  stored encrypted and not loaded with the site (see
  `Feather.Sites.archive_org_keys/1`), so a wrong encryption key does not
  break loading sites.
  """
  use Feather.Schema

  alias Feather.Sites.Languages
  alias Feather.StaticSite.Themes

  @type t :: %__MODULE__{}
  @type mascot_slot :: :footer | :post_end | :projects

  @mascot_slots [:footer, :post_end, :projects]
  @bio_max_length 500

  schema "sites" do
    field :public_id, :string
    field :title, :string
    field :domain, :string
    field :language_code, :string, default: "en"
    field :emoji, :string, default: "🌐"
    field :copyright, :string, default: "© All rights reserved."
    field :theme, :string, default: "feather"
    field :bio, :string
    field :indexnow_key, :string

    field :archive_org_keys, Feather.Encrypted.Map, load_in_query: false

    has_many :site_users, Feather.Sites.SiteUser
    has_many :users, through: [:site_users, :user]
    has_many :invitations, Feather.Sites.Invitation
    has_many :social_media_links, Feather.Sites.SocialMediaLink
    has_many :navigation_items, Feather.Sites.NavigationItem
    has_many :posts, Feather.Content.Post
    has_many :pages, Feather.Content.Page
    has_many :projects, Feather.Content.Project
    has_many :books, Feather.Books.Book
    has_many :images, Feather.Media.Image
    has_one :deployment_target, Feather.Publishing.DeploymentTarget

    belongs_to :footer_mascot_image, Feather.Media.Image
    belongs_to :post_end_mascot_image, Feather.Media.Image
    belongs_to :projects_mascot_image, Feather.Media.Image
    belongs_to :portrait_image, Feather.Media.Image

    timestamps()
  end

  @doc false
  def changeset(site, attrs) do
    site
    |> cast(attrs, [:title, :domain, :language_code, :emoji, :copyright, :theme, :bio])
    |> update_change(:domain, &normalize_domain/1)
    |> Feather.Validations.trim_to_nil(:emoji)
    |> Feather.Validations.trim_to_nil(:bio)
    |> validate_required([:title, :domain, :language_code, :copyright, :theme])
    |> validate_format(:domain, ~r/\A[a-zA-Z0-9\-.]+\z/,
      message: "may only contain letters, digits, dots and dashes"
    )
    |> validate_inclusion(:language_code, Languages.codes())
    |> validate_inclusion(:theme, Themes.keys())
    |> validate_length(:bio, max: @bio_max_length)
    |> Feather.Validations.validate_emoji(:emoji)
    |> unique_constraint(:domain)
    |> unique_constraint(:public_id)
  end

  @doc "The mascot slots, see `Feather.Sites.put_mascot/4`."
  @spec mascot_slots() :: [mascot_slot()]
  def mascot_slots, do: @mascot_slots

  @doc "The association of a mascot slot, e.g. `:footer_mascot_image`."
  @spec mascot_assoc(mascot_slot()) :: atom()
  def mascot_assoc(:footer), do: :footer_mascot_image
  def mascot_assoc(:post_end), do: :post_end_mascot_image
  def mascot_assoc(:projects), do: :projects_mascot_image

  @doc "The associations of all mascot slots, for preloading."
  @spec mascot_assocs() :: [atom()]
  def mascot_assocs, do: Enum.map(@mascot_slots, &mascot_assoc/1)

  @doc "The foreign key of a mascot slot, e.g. `:footer_mascot_image_id`."
  @spec mascot_field(mascot_slot()) :: atom()
  def mascot_field(:footer), do: :footer_mascot_image_id
  def mascot_field(:post_end), do: :post_end_mascot_image_id
  def mascot_field(:projects), do: :projects_mascot_image_id

  @doc "The foreign keys of all mascot slots."
  @spec mascot_fields() :: [atom()]
  def mascot_fields, do: Enum.map(@mascot_slots, &mascot_field/1)

  @doc "The associations of all images of the site, its mascots and its portrait."
  @spec image_assocs() :: [atom()]
  def image_assocs, do: [:portrait_image | mascot_assocs()]

  @doc "The foreign keys of all images of the site, its mascots and its portrait."
  @spec image_fields() :: [atom()]
  def image_fields, do: [:portrait_image_id | mascot_fields()]

  @doc """
  Normalizes what users type as a domain: trims and downcases it and drops
  a leading `http://` or `https://` and any path, so
  `"https://Example.com/blog"` becomes `"example.com"`.
  """
  @spec normalize_domain(String.t() | nil) :: String.t() | nil
  def normalize_domain(domain) when is_binary(domain) do
    domain
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r{\Ahttps?://}, "")
    |> String.replace(~r{/.*\z}s, "")
  end

  def normalize_domain(nil), do: nil

  @doc false
  def create_changeset(site, attrs) do
    site
    |> changeset(attrs)
    |> put_change(:indexnow_key, generate_indexnow_key())
    |> Feather.PublicId.put()
  end

  @doc "A new IndexNow key: 32 lowercase hexadecimal characters."
  @spec generate_indexnow_key() :: String.t()
  def generate_indexnow_key, do: 16 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
end
