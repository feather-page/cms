defmodule FeatherWeb.MCPHelpers do
  @moduledoc """
  Sends requests to the MCP endpoint in ConnCase tests the way a client of
  revision 2026-07-28 does: the version and the client's capabilities in
  `_meta`, mirrored with the method and the tool name in the headers.
  """

  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint FeatherWeb.Endpoint
  @version "2026-07-28"

  @doc "A connection that carries the access token."
  def mcp_conn(access_token),
    do: put_req_header(build_conn(), "authorization", "Bearer #{access_token}")

  @doc """
  Posts the request `method` with `params`, from a connection or with an
  access token.
  """
  def mcp_request(conn_or_token, method, params \\ %{})

  def mcp_request(token, method, params) when is_binary(token),
    do: token |> mcp_conn() |> mcp_request(method, params)

  def mcp_request(%Plug.Conn{} = conn, method, params) do
    conn
    |> put_req_header("mcp-protocol-version", @version)
    |> put_req_header("mcp-method", method)
    |> put_name_header(params)
    |> post_json(mcp_body(method, params))
  end

  @doc "The JSON-RPC request `method` with `params` and the `_meta` of `version`."
  def mcp_body(method, params \\ %{}, version \\ @version) do
    meta = %{
      "io.modelcontextprotocol/protocolVersion" => version,
      "io.modelcontextprotocol/clientCapabilities" => %{},
      "io.modelcontextprotocol/clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
    }

    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => method,
      "params" => Map.put(params, "_meta", meta)
    }
  end

  @doc "Posts `body` as JSON."
  def post_json(conn, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/mcp", Jason.encode!(body))
  end

  @doc "Calls the tool `name` and returns its result."
  def call_tool(access_token, name, arguments \\ %{}) do
    access_token
    |> mcp_request("tools/call", %{"name" => name, "arguments" => arguments})
    |> json_response(200)
    |> Map.fetch!("result")
  end

  defp put_name_header(conn, %{"name" => name}), do: put_req_header(conn, "mcp-name", name)
  defp put_name_header(conn, _params), do: conn
end
