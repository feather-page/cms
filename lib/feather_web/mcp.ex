defmodule FeatherWeb.MCP do
  @moduledoc """
  The MCP server behind `/mcp` (ADR 0031): tools only, one JSON-RPC
  message per request, answered with JSON, without sessions. The tools are
  in `FeatherWeb.MCP.Tools`.

  It speaks two revisions:

    * 2026-07-28, which is stateless: every request names its version and
      the client's capabilities in `_meta`, and mirrors the version, the
      method and the tool name in the `MCP-Protocol-Version`, `Mcp-Method`
      and `Mcp-Name` headers, which must match the body. `server/discover`
      describes the server. Results carry `resultType`, the server in
      `_meta` and, for lists, cache hints.
    * 2025-11-25, for clients that start with `initialize`: they name the
      version only in the `MCP-Protocol-Version` header of later requests.

  Errors follow the HTTP statuses of 2026-07-28; for 2025-11-25 only a
  version error is not answered with 200.
  """

  alias Feather.Accounts.Scope
  alias FeatherWeb.MCP.Tools

  @current "2026-07-28"
  @legacy "2025-11-25"

  @invalid_request -32_600
  @method_not_found -32_601
  @invalid_params -32_602
  @header_mismatch -32_020
  @unsupported_version -32_022

  @meta_version "io.modelcontextprotocol/protocolVersion"
  @meta_capabilities "io.modelcontextprotocol/clientCapabilities"
  @meta_server_info "io.modelcontextprotocol/serverInfo"

  @cache_hints %{ttlMs: 60 * 60 * 1000, cacheScope: "public"}

  @type response :: {:reply, pos_integer(), map()} | :accepted

  @doc """
  Answers a JSON-RPC message (decoded JSON) with the request headers
  (lowercase names) for the scope of the token's user: `{:reply, status,
  body}` for a request, `:accepted` for a notification.
  """
  @spec handle(term(), %{optional(String.t()) => String.t()}, Scope.t()) :: response()
  def handle(message, headers, %Scope{} = scope) do
    case message do
      %{"jsonrpc" => "2.0", "method" => method, "id" => id}
      when is_binary(method) and (is_binary(id) or is_integer(id)) ->
        request(id, method, params(message), headers, scope)

      %{"jsonrpc" => "2.0", "method" => method}
      when is_binary(method) and not is_map_key(message, "id") ->
        :accepted

      _invalid ->
        error_reply(nil, readable_id(message), error(@invalid_request, "Invalid request"))
    end
  end

  defp readable_id(%{"id" => id}) when is_binary(id) or is_integer(id), do: id
  defp readable_id(_message), do: nil

  defp params(%{"params" => %{} = params}), do: params
  defp params(_message), do: %{}

  defp request(id, method, params, headers, scope) do
    case version(method, params, headers) do
      {:ok, version} ->
        with :ok <- check_request(version, method, params, headers),
             {:ok, result} <- call(version, method, params, scope) do
          {:reply, 200, %{jsonrpc: "2.0", id: id, result: complete(version, method, result)}}
        else
          {:error, error} -> error_reply(version, id, error)
        end

      {:error, error} ->
        error_reply(nil, id, error)
    end
  end

  defp version("initialize", _params, _headers), do: {:ok, @legacy}

  defp version(_method, params, headers) do
    case {meta(params)[@meta_version], headers["mcp-protocol-version"]} do
      {@current, _header} -> {:ok, @current}
      {nil, @legacy} -> {:ok, @legacy}
      {nil, nil} -> {:error, missing_header("MCP-Protocol-Version")}
      {nil, @current} -> {:error, missing_meta(@meta_version)}
      {nil, header} -> {:error, unsupported_version(header)}
      {requested, _header} -> {:error, unsupported_version(requested)}
    end
  end

  defp meta(%{"_meta" => %{} = meta}), do: meta
  defp meta(_params), do: %{}

  defp unsupported_version(requested) do
    error(@unsupported_version, "Unsupported protocol version", %{
      supported: [@current, @legacy],
      requested: requested
    })
  end

  defp check_request(@legacy, _method, _params, _headers), do: :ok

  defp check_request(@current, method, params, headers) do
    with :ok <- check_header("MCP-Protocol-Version", headers["mcp-protocol-version"], @current),
         :ok <- check_header("Mcp-Method", headers["mcp-method"], method),
         :ok <- check_name_header(method, params, headers) do
      if is_map(meta(params)[@meta_capabilities]),
        do: :ok,
        else: {:error, missing_meta(@meta_capabilities)}
    end
  end

  defp missing_meta(key), do: error(@invalid_params, "Missing #{key} in _meta")

  defp check_name_header("tools/call", params, headers),
    do: check_header("Mcp-Name", decode_header(headers["mcp-name"]), params["name"])

  defp check_name_header(_method, _params, _headers), do: :ok

  defp check_header(_name, value, value), do: :ok

  defp check_header(name, nil, _body_value), do: {:error, missing_header(name)}

  defp check_header(name, _value, _body_value),
    do:
      {:error,
       error(@header_mismatch, "Header mismatch: the #{name} header differs from the body")}

  defp missing_header(name),
    do: error(@header_mismatch, "Header mismatch: the #{name} header is missing")

  defp decode_header(value) when is_binary(value) do
    with [_, encoded] <- Regex.run(~r/\A=\?base64\?(.*)\?=\z/s, value),
         {:ok, decoded} <- Base.decode64(encoded) do
      decoded
    else
      _not_encoded -> value
    end
  end

  defp decode_header(nil), do: nil

  defp call(@legacy, "initialize", _params, _scope) do
    {:ok,
     %{
       protocolVersion: @legacy,
       capabilities: capabilities(),
       serverInfo: server_info(),
       instructions: instructions()
     }}
  end

  defp call(@legacy, "ping", _params, _scope), do: {:ok, %{}}

  defp call(@current, "server/discover", _params, _scope) do
    {:ok,
     %{
       supportedVersions: [@current, @legacy],
       capabilities: capabilities(),
       instructions: instructions()
     }}
  end

  defp call(_version, "tools/list", _params, _scope), do: {:ok, %{tools: Tools.definitions()}}

  defp call(_version, "tools/call", %{"name" => name} = params, scope) when is_binary(name) do
    case Tools.call(scope, name, params["arguments"] || %{}) do
      {:ok, result} -> {:ok, result}
      :unknown -> {:error, error(@invalid_params, "Unknown tool: #{name}")}
    end
  end

  defp call(_version, "tools/call", _params, _scope),
    do: {:error, error(@invalid_params, "tools/call needs the name of a tool")}

  defp call(_version, method, _params, _scope),
    do: {:error, error(@method_not_found, "Method not found: #{method}")}

  defp capabilities, do: %{tools: %{}}

  defp server_info,
    do: %{name: "feather.page", version: to_string(Application.spec(:feather, :vsn))}

  defp instructions do
    "Works on the feather.page sites of the member who connected you. Tools name a site by " <>
      "its domain; list_sites lists them."
  end

  defp complete(@legacy, _method, result), do: result

  defp complete(@current, method, result) do
    result
    |> Map.merge(%{resultType: "complete", _meta: %{@meta_server_info => server_info()}})
    |> Map.merge(if method in ["server/discover", "tools/list"], do: @cache_hints, else: %{})
  end

  defp error(code, message, data \\ nil)
  defp error(code, message, nil), do: %{code: code, message: message}
  defp error(code, message, data), do: %{code: code, message: message, data: data}

  defp error_reply(version, id, error),
    do: {:reply, status(version, error.code), %{jsonrpc: "2.0", id: id, error: error}}

  defp status(@legacy, code) when code != @unsupported_version, do: 200
  defp status(_version, @method_not_found), do: 404
  defp status(_version, _code), do: 400
end
