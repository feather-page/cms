defmodule FeatherWeb.ApiHelpers do
  @moduledoc """
  Helpers for content API tests: a user with an API token and a site, JSON
  requests and checks against `docs/api/openapi.yml`.
  """

  import ExUnit.Assertions
  import Plug.Conn
  import Phoenix.ConnTest

  alias Feather.Accounts
  alias Feather.Accounts.Scope
  alias Feather.Content.SchemaValidator

  @endpoint FeatherWeb.Endpoint
  @openapi_path Path.expand("../../docs/api/openapi.yml", __DIR__)

  @doc "The parsed OpenAPI document (read once per test run)."
  def openapi do
    case :persistent_term.get({__MODULE__, :openapi}, nil) do
      nil ->
        openapi = YamlElixir.read_from_file!(@openapi_path)
        :persistent_term.put({__MODULE__, :openapi}, openapi)
        openapi

      openapi ->
        openapi
    end
  end

  @doc "The named schemas of the OpenAPI document (`components.schemas`)."
  def openapi_schemas, do: openapi()["components"]["schemas"]

  @doc """
  Setup helper: a user with an API token and a site they are a member of.
  Puts `conn` (sending the token), `token`, `user`, `site` and `scope`
  (with the site) into the context.
  """
  def create_api_user_and_site(%{conn: conn}) do
    user = Feather.AccountsFixtures.user_fixture()
    {:ok, token, _api_token} = Accounts.create_api_token(user, "test")
    scope = Scope.for_user(user)
    site = Feather.SitesFixtures.site_fixture(scope, %{title: "My Blog"})

    %{
      conn: authenticate(conn, token),
      token: token,
      user: user,
      site: site,
      scope: Scope.put_site(scope, site)
    }
  end

  @doc "Sends the API token with every request of the conn."
  def authenticate(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("accept", "application/json")
  end

  @doc "Sends a request with a JSON encoded body."
  def json_request(conn, method, path, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> dispatch(@endpoint, method, path, Jason.encode!(body))
  end

  @doc """
  Asserts that the conn's JSON response matches the OpenAPI response
  schema of the operation, e.g. `("get", "/sites/{site_id}/posts", 200)`.
  Returns the decoded body.
  """
  def assert_openapi_response(conn, method, path, status) do
    body = json_response(conn, status)

    schema =
      get_in(openapi(), [
        "paths",
        path,
        method,
        "responses",
        to_string(status),
        "content",
        "application/json",
        "schema"
      ]) || flunk("No OpenAPI response schema for #{method} #{path} #{status}")

    errors = SchemaValidator.validate(body, schema, openapi_schemas())

    assert errors == [],
           "Response does not match the OpenAPI schema for #{method} #{path} #{status}:\n" <>
             Enum.map_join(errors, "\n", &"#{&1.pointer} #{&1.message}") <>
             "\n\nBody: #{inspect(body)}"

    body
  end
end
