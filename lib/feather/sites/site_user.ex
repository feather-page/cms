defmodule Feather.Sites.SiteUser do
  @moduledoc """
  Membership of a user in a site. Members may manage the site.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  @roles ~w(admin editor)

  schema "site_users" do
    field :role, :string, default: "editor"

    belongs_to :site, Feather.Sites.Site
    belongs_to :user, Feather.Accounts.User

    timestamps()
  end

  @doc "The roles a member may have. Both may manage the site."
  def roles, do: @roles

  @doc false
  def changeset(site_user, attrs) do
    site_user
    |> cast(attrs, [:role])
    |> validate_required([:site_id, :user_id, :role])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:user_id, :site_id], message: "is already a member of this site")
  end
end
