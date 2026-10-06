defmodule FeatherWeb.Plugs.ApiAuth do
  @moduledoc """
  Authenticates content API requests and loads the requested site.

  The caller sends an API token (see `mix feather.api_token`) as
  `Authorization: Bearer <token>`. Without a valid token the request ends
  with `401 {"error": "Unauthorized"}`.

  When the route has a `site_id`, the site is loaded through
  `Feather.Sites.get_site/2`, so only sites the token's user may access
  are found; any other site ends with `404 {"error": "Not found"}`, the
  same as a site that does not exist.

  Assigns `current_scope`, with the site when there is one.
  """

  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Feather.Accounts
  alias Feather.Accounts.{Scope, User}
  alias Feather.Sites
  alias Feather.Sites.Site

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, scope} <- authenticate(conn),
         {:ok, scope} <- put_site(scope, conn.path_params["site_id"]) do
      assign(conn, :current_scope, scope)
    else
      {:error, status, message} ->
        conn
        |> put_status(status)
        |> json(%{error: message})
        |> halt()
    end
  end

  defp authenticate(conn) do
    with [header | _] <- get_req_header(conn, "authorization"),
         {:ok, token} <- bearer_token(header),
         %User{} = user <- Accounts.get_user_by_api_token(token) do
      {:ok, Scope.for_user(user)}
    else
      _ -> {:error, :unauthorized, "Unauthorized"}
    end
  end

  defp bearer_token(header) do
    case String.split(String.trim(header), " ", parts: 2) do
      [scheme, token] when token != "" ->
        if String.downcase(scheme) == "bearer", do: {:ok, String.trim(token)}, else: :error

      _ ->
        :error
    end
  end

  defp put_site(scope, nil), do: {:ok, scope}

  defp put_site(scope, site_id) do
    case Sites.get_site(scope, site_id) do
      %Site{} = site -> {:ok, Scope.put_site(scope, site)}
      nil -> {:error, :not_found, "Not found"}
    end
  end
end
