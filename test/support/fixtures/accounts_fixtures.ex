defmodule Feather.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Feather.Accounts` context.
  """

  import Ecto.Query

  alias Feather.Accounts
  alias Feather.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  @doc """
  A confirmed user, as created by an invitation or `mix feather.create_user`.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.create_user()

    user
  end

  @doc """
  A super admin.
  """
  def super_admin_fixture(attrs \\ %{}) do
    {:ok, user} = attrs |> user_fixture() |> Accounts.set_super_admin(true)
    user
  end

  @doc """
  A user who never confirmed their email (only reachable through data
  imported from elsewhere; kept to test the confirmation flow).
  """
  def unconfirmed_user_fixture(attrs \\ %{}) do
    attrs
    |> valid_user_attributes()
    |> then(&Accounts.User.email_changeset(%Accounts.User{}, &1))
    |> Feather.Repo.insert!()
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Feather.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Feather.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Feather.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
