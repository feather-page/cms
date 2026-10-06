defmodule FeatherWeb.Api.CaddyController do
  @moduledoc """
  Answers Caddy's on-demand TLS `ask` (see `ops/Caddyfile`): 200 when we
  host the domain on an internal deployment target, 404 otherwise, so
  Caddy only requests certificates for our own sites. Unauthenticated.
  """
  use FeatherWeb, :controller

  alias Feather.Publishing

  def check_domain(conn, %{"domain" => domain}) when is_binary(domain) do
    if Publishing.internally_hosted?(domain) do
      send_resp(conn, :ok, "")
    else
      send_resp(conn, :not_found, "")
    end
  end

  def check_domain(conn, _params), do: send_resp(conn, :not_found, "")
end
