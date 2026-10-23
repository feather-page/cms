defmodule FeatherWeb.MCPController do
  @moduledoc """
  The MCP endpoint (`FeatherWeb.MCP`), behind the router's `:mcp`
  pipeline, which refuses requests from web pages of other origins and
  requires a valid access token (`FeatherWeb.Plugs.RequireAccessToken`).
  It takes one JSON-RPC message per POST; GET and DELETE, which earlier
  revisions used for streams and sessions, are refused.
  """
  use FeatherWeb, :controller

  alias FeatherWeb.MCP

  def create(conn, _params) do
    headers = Map.new(conn.req_headers)

    case MCP.handle(conn.body_params, headers, conn.assigns.current_scope) do
      {:reply, status, body} -> conn |> put_status(status) |> json(body)
      :accepted -> send_resp(conn, :accepted, "")
    end
  end

  def method_not_allowed(conn, _params) do
    conn
    |> put_resp_header("allow", "POST")
    |> send_resp(:method_not_allowed, "")
  end
end
