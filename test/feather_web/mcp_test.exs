defmodule FeatherWeb.MCPTest do
  use Feather.DataCase

  alias Feather.Accounts.Scope
  alias FeatherWeb.MCP

  @current "2026-07-28"
  @legacy "2025-11-25"

  setup do
    %{scope: Scope.for_user(user_fixture())}
  end

  defp request(method, params \\ %{}, meta \\ %{}) do
    meta =
      Map.merge(
        %{
          "io.modelcontextprotocol/protocolVersion" => @current,
          "io.modelcontextprotocol/clientCapabilities" => %{}
        },
        meta
      )

    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => method,
      "params" => Map.put(params, "_meta", meta)
    }
  end

  defp headers(method, overrides \\ %{}) do
    %{"mcp-protocol-version" => @current, "mcp-method" => method}
    |> Map.merge(overrides)
    |> Map.reject(fn {_name, value} -> is_nil(value) end)
  end

  defp call_tool(scope, name, arguments, header_name \\ nil) do
    MCP.handle(
      request("tools/call", %{"name" => name, "arguments" => arguments}),
      headers("tools/call", %{"mcp-name" => header_name || name}),
      scope
    )
  end

  defp legacy(method), do: %{"jsonrpc" => "2.0", "id" => 1, "method" => method}

  describe "messages" do
    test "a notification is accepted without an answer", %{scope: scope} do
      notification = %{"jsonrpc" => "2.0", "method" => "notifications/cancelled"}

      assert MCP.handle(notification, %{}, scope) == :accepted
    end

    test "anything else that is no request is invalid", %{scope: scope} do
      for message <- [
            %{"id" => 1, "method" => "tools/list"},
            %{"jsonrpc" => "2.0", "id" => nil, "method" => "tools/list"},
            %{"jsonrpc" => "2.0", "id" => 1},
            %{"_json" => [legacy("tools/list")]}
          ] do
        assert {:reply, 400, %{error: %{code: -32_600}}} = MCP.handle(message, %{}, scope)
      end
    end
  end

  describe "revision 2026-07-28" do
    test "results name the server, lists carry cache hints", %{scope: scope} do
      assert {:reply, 200, %{id: 1, result: list}} =
               MCP.handle(request("tools/list"), headers("tools/list"), scope)

      assert %{resultType: "complete", ttlMs: 3_600_000, cacheScope: "public"} = list
      assert %{"io.modelcontextprotocol/serverInfo" => %{name: "feather.page"}} = list._meta

      assert {:reply, 200, %{result: call}} = call_tool(scope, "list_sites", %{})
      assert %{resultType: "complete", _meta: %{}} = call
      refute Map.has_key?(call, :ttlMs)
    end

    test "a request must name the version and the client's capabilities in _meta", %{
      scope: scope
    } do
      without_version = update_in(request("tools/list"), ["params", "_meta"], &Map.take(&1, []))

      without_capabilities =
        request("tools/list", %{}, %{"io.modelcontextprotocol/clientCapabilities" => nil})

      for message <- [without_version, without_capabilities] do
        assert {:reply, 400, %{error: %{code: -32_602}}} =
                 MCP.handle(message, headers("tools/list"), scope)
      end
    end

    test "a request without a version in the header or in _meta is a header error", %{
      scope: scope
    } do
      without_version = update_in(request("tools/list"), ["params", "_meta"], &Map.take(&1, []))

      assert {:reply, 400, %{error: %{code: -32_020, message: message}}} =
               MCP.handle(
                 without_version,
                 headers("tools/list", %{"mcp-protocol-version" => nil}),
                 scope
               )

      assert message == "Header mismatch: the MCP-Protocol-Version header is missing"
    end

    test "the mirrored headers must be there and match the body", %{scope: scope} do
      for overrides <- [
            %{"mcp-protocol-version" => nil},
            %{"mcp-method" => "tools/list"},
            %{"mcp-name" => nil}
          ] do
        assert {:reply, 400, %{error: %{code: -32_020}}} =
                 MCP.handle(
                   request("tools/call", %{"name" => "list_sites"}),
                   headers("tools/call", Map.merge(%{"mcp-name" => "list_sites"}, overrides)),
                   scope
                 )
      end
    end

    test "a tool name in the header may be Base64-encoded", %{scope: scope} do
      encoded = "=?base64?" <> Base.encode64("list_sites") <> "?="

      assert {:reply, 200, %{result: %{isError: false}}} =
               call_tool(scope, "list_sites", %{}, encoded)
    end

    test "methods of other revisions are not found", %{scope: scope} do
      for method <- ["ping", "resources/list"] do
        assert {:reply, 404, %{error: %{code: -32_601}}} =
                 MCP.handle(request(method), headers(method), scope)
      end
    end

    test "an unknown tool is a protocol error", %{scope: scope} do
      assert {:reply, 400, %{error: %{code: -32_602, message: "Unknown tool: delete_site"}}} =
               call_tool(scope, "delete_site", %{})
    end

    test "arguments that do not fit the tool come back as a tool error", %{scope: scope} do
      for {arguments, message} <- [
            {%{}, "Invalid arguments: missing required fields: site"},
            {%{"site" => 1}, "Invalid arguments: site: expected string, got integer"}
          ] do
        assert {:reply, 200, %{result: %{isError: true, content: [%{text: ^message}]}}} =
                 call_tool(scope, "deploy_site", arguments)
      end
    end
  end

  describe "revision 2025-11-25" do
    test "requests name the version only in the header", %{scope: scope} do
      headers = %{"mcp-protocol-version" => @legacy}

      assert {:reply, 200, %{result: %{tools: [_ | _]} = result}} =
               MCP.handle(legacy("tools/list"), headers, scope)

      refute Map.has_key?(result, :resultType)

      assert MCP.handle(legacy("ping"), headers, scope) ==
               {:reply, 200, %{jsonrpc: "2.0", id: 1, result: %{}}}

      assert {:reply, 200, %{error: %{code: -32_601}}} =
               MCP.handle(legacy("server/discover"), headers, scope)
    end

    test "initialize answers with 2025-11-25 whichever version the client asks for", %{
      scope: scope
    } do
      message = put_in(legacy("initialize")["params"], %{"protocolVersion" => "2025-06-18"})

      assert {:reply, 200, %{result: %{protocolVersion: @legacy}}} =
               MCP.handle(message, %{}, scope)
    end

    test "other versions get the version error", %{scope: scope} do
      assert {:reply, 400, %{error: %{code: -32_022, data: data}}} =
               MCP.handle(legacy("tools/list"), %{"mcp-protocol-version" => "2025-06-18"}, scope)

      assert data == %{supported: [@current, @legacy], requested: "2025-06-18"}
    end
  end
end
