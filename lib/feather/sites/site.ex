defmodule Feather.Sites.Site do
  @moduledoc """
  A managed website with its own domain; the container for all content.
  """
  use Feather.Schema

  alias Feather.Sites.Languages

  @type t :: %__MODULE__{}

  schema "sites" do
    field :public_id, :string
    field :title, :string
    field :domain, :string
    field :language_code, :string, default: "en"
    field :emoji, :string, default: "🌐"
    field :copyright, :string, default: "© All rights reserved."

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
    has_many :deployment_targets, Feather.Publishing.DeploymentTarget

    timestamps()
  end

  @doc false
  def changeset(site, attrs) do
    site
    |> cast(attrs, [:title, :domain, :language_code, :emoji, :copyright])
    |> update_change(:domain, &String.trim/1)
    |> Feather.Validations.trim_to_nil(:emoji)
    |> validate_required([:title, :domain, :language_code, :copyright])
    |> validate_format(:domain, ~r/\A[a-zA-Z0-9\-.]+\z/,
      message: "may only contain letters, digits, dots and dashes"
    )
    |> validate_inclusion(:language_code, Languages.codes())
    |> Feather.Validations.validate_emoji(:emoji)
    |> unique_constraint(:domain)
    |> unique_constraint(:public_id)
  end

  @doc false
  def create_changeset(site, attrs) do
    site
    |> changeset(attrs)
    |> Feather.PublicId.put_new()
  end
end
