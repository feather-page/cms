defmodule Feather.SitesFixtures do
  @moduledoc """
  Test helpers for sites, members, invitations and social media links.
  """

  alias Feather.Accounts.Scope
  alias Feather.Sites

  def unique_domain, do: "site#{System.unique_integer([:positive])}.example.com"

  def valid_site_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "My Site",
      domain: unique_domain(),
      language_code: "en"
    })
  end

  @doc """
  Creates a site through `Feather.Sites.create_site/2` (so it has a member,
  a homepage and a staging target). Pass a scope or a user to own it;
  without one a new user is created.
  """
  def site_fixture(scope_or_user \\ nil, attrs \\ %{})

  def site_fixture(nil, attrs), do: site_fixture(Feather.AccountsFixtures.user_fixture(), attrs)

  def site_fixture(%Feather.Accounts.User{} = user, attrs),
    do: site_fixture(Scope.for_user(user), attrs)

  def site_fixture(%Scope{} = scope, attrs) do
    {:ok, site} = Sites.create_site(scope, valid_site_attributes(attrs))
    site
  end

  @doc """
  A scope with a fresh user and a site of theirs.
  """
  def site_scope_fixture(attrs \\ %{}) do
    user = Feather.AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    site = site_fixture(scope, attrs)
    Scope.put_site(scope, site)
  end

  def invitation_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, invitation} =
      Sites.create_invitation(
        scope,
        Enum.into(attrs, %{email: Feather.AccountsFixtures.unique_user_email()})
      )

    invitation
  end

  def social_media_link_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, link} =
      Sites.create_social_media_link(
        scope,
        Enum.into(attrs, %{name: "GitHub", url: "https://github.com/johndoe", icon: "github"})
      )

    link
  end
end
