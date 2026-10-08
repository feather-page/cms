defmodule Feather.Accounts.User do
  @moduledoc """
  A person who logs in to the CMS. There are no passwords: users log in
  with a magic link sent by email. Super admins may access every site.
  """
  use Feather.Schema

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :super_admin, :boolean, default: false
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    has_many :api_tokens, Feather.Accounts.ApiToken
    has_many :site_users, Feather.Sites.SiteUser
    has_many :sites, through: [:site_users, :site]

    timestamps()
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> update_change(:email, &normalize_email/1)
    |> validate_email(opts)
  end

  defp normalize_email(email), do: email |> String.trim() |> String.downcase()

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Feather.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user_or_changeset) do
    change(user_or_changeset, confirmed_at: DateTime.utc_now(:second))
  end
end
