defmodule FeatherWeb.ConnCase do
  @moduledoc """
  The test case for tests that need a connection.

  Database access is sandboxed like in `Feather.DataCase`, and for the
  same reason tests are synchronous: `use FeatherWeb.ConnCase`
  raises.

  Setup helpers for quick tests:

      setup [:register_and_log_in_user, :create_site_for_user]

  gives you `conn` (logged in), `user`, `site` and `scope` (with the site).
  """

  use ExUnit.CaseTemplate

  using opts do
    if opts[:async] do
      raise ArgumentError,
            "FeatherWeb.ConnCase does not support async: true; SQLite tests run synchronously"
    end

    quote do
      # The default endpoint for testing
      @endpoint FeatherWeb.Endpoint

      use FeatherWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import FeatherWeb.ConnCase

      import Feather.AccountsFixtures
      import Feather.SitesFixtures
      import Feather.ContentFixtures
      import Feather.BooksFixtures
      import Feather.MediaFixtures
      import Feather.PublishingFixtures
    end
  end

  setup tags do
    Feather.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that creates a user and logs them in.

      setup :register_and_log_in_user

  Puts `conn`, `user` and `scope` into the test context.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    user = Feather.AccountsFixtures.user_fixture()
    scope = Feather.Accounts.Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Setup helper that creates a site for the context's user (as a member) and
  puts `site` and a `scope` with that site into the context.

      setup [:register_and_log_in_user, :create_site_for_user]
  """
  def create_site_for_user(%{user: user} = context) do
    scope = context[:scope] || Feather.Accounts.Scope.for_user(user)
    site = Feather.SitesFixtures.site_fixture(scope)
    %{site: site, scope: Feather.Accounts.Scope.put_site(scope, site)}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = Feather.Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    Feather.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end
end
