defmodule FeatherWeb.McpController do
  @moduledoc """
  The MCP endpoint, reached only with a valid access token
  (`FeatherWeb.Plugs.RequireAccessToken`). It answers every JSON-RPC
  request with the error for an unknown method.
  """
  use FeatherWeb, :controller

  def create(conn, params) do
    json(conn, %{
      jsonrpc: "2.0",
      id: params["id"],
      error: %{code: -32_601, message: "Method not found"}
    })
  end
end
