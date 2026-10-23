defmodule Feather.OAuth.ClientMetadataTest do
  use ExUnit.Case, async: true

  alias Feather.OAuth.ClientMetadata

  @client_id "https://claude.ai/oauth/mcp-oauth-client-metadata"
  @redirect_uri "https://claude.ai/api/mcp/auth_callback"

  @document %{
    "client_id" => @client_id,
    "client_name" => "Claude",
    "redirect_uris" => [@redirect_uri, "http://localhost:3118/callback"],
    "token_endpoint_auth_method" => "none"
  }

  defp serve(document) do
    Req.Test.stub(ClientMetadata, fn conn ->
      send(self(), {:fetched, conn.host, conn.request_path})
      Req.Test.json(conn, document)
    end)
  end

  defp metadata(redirect_uris) do
    %ClientMetadata{client_id: @client_id, client_name: "Claude", redirect_uris: redirect_uris}
  end

  describe "fetch/1" do
    test "reads the client's name and redirect URIs from its URL" do
      serve(@document)

      assert ClientMetadata.fetch(@client_id) ==
               {:ok, metadata([@redirect_uri, "http://localhost:3118/callback"])}

      assert_received {:fetched, "claude.ai", "/oauth/mcp-oauth-client-metadata"}
    end

    test "accepts a document without an auth method" do
      serve(Map.delete(@document, "token_endpoint_auth_method"))

      assert {:ok, %ClientMetadata{client_name: "Claude"}} = ClientMetadata.fetch(@client_id)
    end

    test "refuses a client id that is not an HTTPS URL with a path" do
      serve(@document)

      for client_id <- [
            "http://claude.ai/oauth/mcp-oauth-client-metadata",
            "https://claude.ai",
            "claude",
            "https://user@claude.ai/oauth/metadata",
            "https://claude.ai/oauth/metadata#client",
            "https://claude.ai/oauth/../metadata",
            nil,
            ["https://claude.ai/oauth/metadata"]
          ] do
        assert ClientMetadata.fetch(client_id) == {:error, :invalid_client_id}, inspect(client_id)
      end

      refute_received {:fetched, _host, _path}
    end

    test "refuses a document whose client_id differs from its URL" do
      serve(%{@document | "client_id" => "https://evil.example/oauth/metadata"})

      assert ClientMetadata.fetch(@client_id) == {:error, :client_id_mismatch}
    end

    test "refuses a document without a name or redirect URIs" do
      for document <- [
            Map.delete(@document, "client_name"),
            %{@document | "client_name" => " "},
            Map.delete(@document, "redirect_uris"),
            %{@document | "redirect_uris" => []},
            %{@document | "redirect_uris" => @redirect_uri},
            Map.delete(@document, "client_id"),
            [@document]
          ] do
        serve(document)
        assert ClientMetadata.fetch(@client_id) == {:error, :invalid_metadata}, inspect(document)
      end
    end

    test "refuses a client name longer than 100 characters" do
      serve(%{@document | "client_name" => String.duplicate("C", 100)})
      assert {:ok, %ClientMetadata{}} = ClientMetadata.fetch(@client_id)

      serve(%{@document | "client_name" => String.duplicate("C", 101)})
      assert ClientMetadata.fetch(@client_id) == {:error, :invalid_metadata}
    end

    test "refuses a document that is not JSON" do
      Req.Test.stub(ClientMetadata, &Req.Test.html(&1, "<h1>Claude</h1>"))

      assert ClientMetadata.fetch(@client_id) == {:error, :invalid_metadata}
    end

    test "refuses a client that authenticates in another way than none" do
      serve(%{@document | "token_endpoint_auth_method" => "client_secret_basic"})

      assert ClientMetadata.fetch(@client_id) == {:error, :unsupported_auth_method}
    end

    test "refuses a document that cannot be loaded, redirects or is larger than 5 KB" do
      Req.Test.stub(ClientMetadata, &Plug.Conn.send_resp(&1, 404, "not found"))
      assert ClientMetadata.fetch(@client_id) == {:error, :unreachable}

      Req.Test.stub(ClientMetadata, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "https://claude.ai/other-metadata")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert ClientMetadata.fetch(@client_id) == {:error, :unreachable}

      serve(%{@document | "client_name" => String.duplicate("C", 5_000)})
      assert ClientMetadata.fetch(@client_id) == {:error, :unreachable}
    end

    test "does not fetch from a private address" do
      serve(%{@document | "client_id" => "https://10.0.0.7/metadata"})

      assert ClientMetadata.fetch("https://10.0.0.7/metadata") == {:error, :unreachable}
      refute_received {:fetched, _host, _path}
    end
  end

  describe "check_redirect_uri/2" do
    test "accepts a listed redirect URI" do
      assert ClientMetadata.check_redirect_uri(metadata([@redirect_uri]), @redirect_uri) == :ok
    end

    test "refuses a redirect URI that is not listed" do
      for redirect_uri <- [
            "https://claude.ai/api/mcp/other_callback",
            "https://claude.ai/api/mcp/auth_callback?next=evil",
            "https://claude.ai:8443/api/mcp/auth_callback",
            nil
          ] do
        assert ClientMetadata.check_redirect_uri(metadata([@redirect_uri]), redirect_uri) ==
                 {:error, :invalid_redirect_uri}
      end
    end

    test "accepts a loopback redirect URI on any port" do
      listed = ["http://localhost:3118/callback", "http://127.0.0.1/callback"]

      for redirect_uri <- ["http://localhost:54321/callback", "http://127.0.0.1:8080/callback"] do
        assert ClientMetadata.check_redirect_uri(metadata(listed), redirect_uri) == :ok
      end

      for redirect_uri <- ["http://localhost:54321/other", "http://127.0.0.1:8080/other"] do
        assert ClientMetadata.check_redirect_uri(metadata(listed), redirect_uri) ==
                 {:error, :invalid_redirect_uri}
      end
    end

    test "refuses plain HTTP and fragments, even when listed" do
      for redirect_uri <- ["http://claude.ai/callback", "https://claude.ai/callback#done"] do
        assert ClientMetadata.check_redirect_uri(metadata([redirect_uri]), redirect_uri) ==
                 {:error, :invalid_redirect_uri}
      end
    end

    test "refuses a host that is not a plain DNS name" do
      redirect_uri = "https://claude.ai;evil/callback"

      assert ClientMetadata.check_redirect_uri(metadata([redirect_uri]), redirect_uri) ==
               {:error, :invalid_redirect_uri}
    end
  end
end
