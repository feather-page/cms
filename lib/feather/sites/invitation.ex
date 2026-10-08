defmodule Feather.Sites.Invitation do
  @moduledoc """
  An invitation for an email address to become a member of a site.

  The acceptance link carries a `Phoenix.Token` signed with the invitation
  id and `updated_at` (see `Feather.Sites.invitation_token/1`), valid for
  7 days: sending the invitation again invalidates earlier links. Nothing
  else token-related is stored; an accepted invitation can't be accepted
  again.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "invitations" do
    field :email, :string
    field :accepted_at, :utc_datetime_usec

    belongs_to :site, Feather.Sites.Site
    belongs_to :inviting_user, Feather.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email])
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique([:email, :site_id], Feather.Repo,
      message: "has already been invited"
    )
    |> unique_constraint([:email, :site_id], message: "has already been invited")
  end

  @doc "Returns true once the invitation has been accepted."
  def accepted?(%__MODULE__{accepted_at: accepted_at}), do: not is_nil(accepted_at)
end
