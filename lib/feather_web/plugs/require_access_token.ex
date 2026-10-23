defmodule FeatherWeb.Plugs.RequireAccessToken do
  @moduledoc """
  Lets requests to the MCP endpoint through only with a valid access token
  (`Authorization: Bearer <token>`, see `Feather.OAuth.authenticate/1`) and
  assigns the `current_scope` of the token's user.

  Any other request ends with 401 and a `WWW-Authenticate` challenge that
  points the client to the protected resource metadata, where it finds out
  how to get a token (ADR 0032).
  """

  @behaviour Plug

  use FeatherWeb, :verified_routes

  import Plug.Conn

  alias Feather.Accounts.Scope
  alias Feather.OAuth

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, user} <- OAuth.authenticate(token) do
      assign(conn, :current_scope, Scope.for_user(user))
    else
      :missing ->
        unauthorized(conn, ~s(Bearer resource_metadata="#{metadata_url()}"))

      :error ->
        unauthorized(
          conn,
          ~s(Bearer error="invalid_token", resource_metadata="#{metadata_url()}")
        )
    end
  end

  defp bearer_token(conn) do
    with [header | _] <- get_req_header(conn, "authorization"),
         [scheme, token] <- String.split(header, " ", parts: 2),
         "bearer" <- String.downcase(scheme) do
      {:ok, String.trim(token)}
    else
      _ -> :missing
    end
  end

  defp metadata_url, do: url(~p"/.well-known/oauth-protected-resource/mcp")

  defp unauthorized(conn, challenge) do
    conn
    |> put_resp_header("www-authenticate", challenge)
    |> send_resp(:unauthorized, "")
    |> halt()
  end
end
