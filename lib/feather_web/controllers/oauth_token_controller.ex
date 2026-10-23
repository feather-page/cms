defmodule FeatherWeb.OAuthTokenController do
  @moduledoc """
  The token endpoint (ADR 0032): clients exchange an authorization code or
  a refresh token for new tokens (`Feather.OAuth.token/2`). Clients are
  public: they send their `client_id` and no secret.
  """
  use FeatherWeb, :controller

  alias Feather.OAuth

  def create(conn, _params) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    case OAuth.token(conn.body_params, url(~p"/mcp")) do
      {:ok, tokens} ->
        json(conn, Map.put(tokens, :token_type, "Bearer"))

      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: error})
    end
  end
end
