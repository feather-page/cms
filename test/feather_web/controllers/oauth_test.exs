defmodule FeatherWeb.OAuthTest do
  use FeatherWeb.ConnCase

  @state "af0ifjsldkj"

  setup do
    stub_client_metadata()
    %{verifier: code_verifier()}
  end

  defp authorization_params(verifier, overrides \\ %{}) do
    Map.merge(
      %{
        "response_type" => "code",
        "client_id" => claude_client_id(),
        "redirect_uri" => claude_redirect_uri(),
        "code_challenge" => code_challenge(verifier),
        "code_challenge_method" => "S256",
        "resource" => url(~p"/mcp"),
        "state" => @state
      },
      overrides
    )
  end

  defp exchange(code, verifier) do
    post(build_conn(), ~p"/oauth/token", %{
      "grant_type" => "authorization_code",
      "code" => code,
      "redirect_uri" => claude_redirect_uri(),
      "client_id" => claude_client_id(),
      "code_verifier" => verifier,
      "resource" => url(~p"/mcp")
    })
  end

  defp refresh(refresh_token) do
    post(build_conn(), ~p"/oauth/token", %{
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token,
      "client_id" => claude_client_id(),
      "resource" => url(~p"/mcp")
    })
  end

  defp call_mcp(access_token), do: mcp_request(access_token, "tools/list")

  defp callback_params(conn) do
    location = redirected_to(conn)
    assert String.starts_with?(location, claude_redirect_uri() <> "?")
    location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
  end

  defp decide(conn, verifier, decision) do
    post(
      conn,
      ~p"/oauth/authorize",
      Map.put(authorization_params(verifier), "decision", decision)
    )
  end

  defp allow(conn, verifier),
    do: conn |> decide(verifier, "allow") |> callback_params() |> Map.fetch!("code")

  describe "connecting a client" do
    test "from a 401 on /mcp through the login and consent to a token that opens /mcp", %{
      conn: conn,
      verifier: verifier
    } do
      user = user_fixture()
      site_fixture(user, domain: "notes.example")

      conn = post(conn, ~p"/mcp", %{})
      assert conn.status == 401
      [challenge] = get_resp_header(conn, "www-authenticate")
      [_, metadata_url] = Regex.run(~r/\ABearer resource_metadata="([^"]+)"\z/, challenge)

      resource = build_conn() |> get(metadata_url) |> json_response(200)
      assert resource["resource"] == url(~p"/mcp")
      [issuer] = resource["authorization_servers"]

      server =
        build_conn()
        |> get(issuer <> "/.well-known/oauth-authorization-server")
        |> json_response(200)

      assert server["issuer"] == issuer

      authorize_url =
        server["authorization_endpoint"] <>
          "?" <> URI.encode_query(authorization_params(verifier))

      conn = get(build_conn(), authorize_url)
      assert redirected_to(conn) == ~p"/users/log-in"

      {magic_link_token, _} = generate_user_magic_link_token(user)
      conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => magic_link_token}})
      consent_path = redirected_to(conn)

      assert consent_path ==
               "/oauth/authorize?" <> URI.encode_query(authorization_params(verifier))

      conn = get(conn, consent_path)
      consent = conn |> html_response(200) |> LazyHTML.from_document()
      assert consent |> LazyHTML.query("#consent-client") |> LazyHTML.text() == "Claude"
      assert consent |> LazyHTML.query("#consent-redirect-host") |> LazyHTML.text() == "claude.ai"

      conn = decide(conn, verifier, "allow")
      assert %{"code" => code, "state" => @state, "iss" => ^issuer} = callback_params(conn)

      tokens = code |> exchange(verifier) |> json_response(200)
      assert %{"token_type" => "Bearer", "expires_in" => 3600, "refresh_token" => _} = tokens

      assert %{"structuredContent" => %{"sites" => [%{"domain" => "notes.example"}]}} =
               call_tool(tokens["access_token"], "list_sites")

      settings =
        conn |> get(~p"/users/settings") |> html_response(200) |> LazyHTML.from_document()

      assert settings |> LazyHTML.query("#connected-app-list") |> LazyHTML.text() =~ "Claude"
    end

    test "the consent page lets the member deny", %{conn: conn, verifier: verifier} do
      conn = conn |> log_in_user(user_fixture()) |> decide(verifier, "deny")

      assert callback_params(conn) == %{
               "error" => "access_denied",
               "state" => @state,
               "iss" => FeatherWeb.Endpoint.url()
             }
    end

    test "the consent page lets its form send the member back to the client", %{
      conn: conn,
      verifier: verifier
    } do
      conn =
        conn
        |> log_in_user(user_fixture())
        |> get(~p"/oauth/authorize?#{authorization_params(verifier)}")

      [policy] = get_resp_header(conn, "content-security-policy")
      assert "form-action 'self' https://claude.ai" in String.split(policy, "; ")
    end

    test "neither the consent page nor the error page can be framed", %{
      conn: conn,
      verifier: verifier
    } do
      conn = log_in_user(conn, user_fixture())
      untrusted = %{"redirect_uri" => "https://evil.example/callback"}

      for params <- [authorization_params(verifier), authorization_params(verifier, untrusted)] do
        [policy] =
          conn
          |> get(~p"/oauth/authorize?#{params}")
          |> get_resp_header("content-security-policy")

        assert "frame-ancestors 'none'" in String.split(policy, "; ")
      end
    end

    test "the consent page warns when the client listens on the member's computer", %{
      conn: conn,
      verifier: verifier
    } do
      stub_client_metadata(%{"redirect_uris" => ["http://localhost/callback"]})

      params =
        authorization_params(verifier, %{"redirect_uri" => "http://localhost:43117/callback"})

      conn = conn |> log_in_user(user_fixture()) |> get(~p"/oauth/authorize?#{params}")

      consent = conn |> html_response(200) |> LazyHTML.from_document()
      assert consent |> LazyHTML.query("#consent-redirect-host") |> LazyHTML.text() == "localhost"
      assert consent |> LazyHTML.query("#consent-loopback-warning") |> Enum.count() == 1

      [policy] = get_resp_header(conn, "content-security-policy")
      assert "form-action 'self' http://localhost:43117" in String.split(policy, "; ")
    end
  end

  describe "refused" do
    setup %{conn: conn} do
      %{conn: log_in_user(conn, user_fixture())}
    end

    test "a wrong code verifier", %{conn: conn, verifier: verifier} do
      code = allow(conn, verifier)

      assert code |> exchange(code_verifier()) |> json_response(400) == %{
               "error" => "invalid_grant"
             }
    end

    test "a reused code", %{conn: conn, verifier: verifier} do
      code = allow(conn, verifier)
      assert code |> exchange(verifier) |> json_response(200)

      assert code |> exchange(verifier) |> json_response(400) == %{"error" => "invalid_grant"}
    end

    test "a request the member cannot decide on is named to them, not sent back", %{
      conn: conn,
      verifier: verifier
    } do
      for {overrides, message} <- [
            {%{"response_type" => "token"}, "kind of access"},
            {%{"code_challenge" => "too-short"}, "incomplete"},
            {%{"resource" => "https://other.example/mcp"}, "server other than Feather"}
          ] do
        params = authorization_params(verifier, overrides)

        for conn <- [
              get(conn, ~p"/oauth/authorize?#{params}"),
              post(conn, ~p"/oauth/authorize", Map.put(params, "decision", "deny"))
            ] do
          assert html_response(conn, 400) =~ message
          assert get_resp_header(conn, "location") == []
        end
      end
    end

    test "a client that cannot be trusted is named to the member, not redirected to", %{
      conn: conn,
      verifier: verifier
    } do
      params =
        authorization_params(verifier, %{"redirect_uri" => "https://evil.example/callback"})

      conn = get(conn, ~p"/oauth/authorize?#{params}")

      assert html_response(conn, 400) =~ "does not list"
    end

    test "an allow for a redirect URI the client does not list issues no code", %{
      conn: conn,
      verifier: verifier
    } do
      params =
        authorization_params(verifier, %{
          "redirect_uri" => "https://evil.example/callback",
          "decision" => "allow"
        })

      conn = post(conn, ~p"/oauth/authorize", params)

      assert html_response(conn, 400) =~ "does not list"
      assert Feather.Repo.aggregate(Feather.OAuth.AuthorizationCode, :count) == 0
    end

    test "an allow while logged out issues no code", %{verifier: verifier} do
      params = Map.put(authorization_params(verifier), "decision", "allow")

      conn = post(build_conn(), ~p"/oauth/authorize", params)

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Feather.Repo.aggregate(Feather.OAuth.AuthorizationCode, :count) == 0
    end

    test "an expired connection", %{conn: conn, verifier: verifier} do
      code = allow(conn, verifier)
      tokens = code |> exchange(verifier) |> json_response(200)
      [app] = Feather.Repo.all(Feather.OAuth.ConnectedApp)
      age_connected_app(app, 90)

      assert call_mcp(tokens["access_token"]).status == 401

      assert tokens["refresh_token"] |> refresh() |> json_response(400) == %{
               "error" => "invalid_grant"
             }
    end

    test "a refresh token used twice", %{conn: conn, verifier: verifier} do
      code = allow(conn, verifier)
      %{"refresh_token" => refresh_token} = code |> exchange(verifier) |> json_response(200)

      tokens = refresh_token |> refresh() |> json_response(200)
      assert call_mcp(tokens["access_token"]).status == 200

      assert refresh_token |> refresh() |> json_response(400) == %{"error" => "invalid_grant"}
    end
  end

  describe "token responses" do
    test "are not cached", %{conn: conn, verifier: verifier} do
      code = conn |> log_in_user(user_fixture()) |> allow(verifier)

      for conn <- [exchange(code, verifier), exchange(code, verifier)] do
        assert get_resp_header(conn, "cache-control") == ["no-store"]
      end
    end

    test "answer a form-encoded request", %{conn: conn, verifier: verifier} do
      code = conn |> log_in_user(user_fixture()) |> allow(verifier)

      body =
        URI.encode_query(%{
          "grant_type" => "authorization_code",
          "code" => code,
          "redirect_uri" => claude_redirect_uri(),
          "client_id" => claude_client_id(),
          "code_verifier" => verifier
        })

      conn =
        build_conn()
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/oauth/token", body)

      assert %{"access_token" => _, "token_type" => "Bearer"} = json_response(conn, 200)
    end
  end

  describe "/mcp" do
    test "answers 401 with an invalid_token error for a token it does not know" do
      conn = call_mcp("unknown")

      assert conn.status == 401

      assert get_resp_header(conn, "www-authenticate") == [
               ~s(Bearer error="invalid_token", resource_metadata="#{url(~p"/.well-known/oauth-protected-resource/mcp")}")
             ]
    end

    test "answers 401 to a logged-in browser session without a token", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> post(~p"/mcp", %{})

      assert conn.status == 401
    end

    test "takes the bearer scheme in any case and assigns the token's user", %{conn: conn} do
      user = user_fixture()
      %{access_token: access_token} = connected_app_fixture(user)

      conn =
        conn
        |> put_req_header("authorization", "bearer #{access_token}")
        |> mcp_request("tools/list")

      assert conn.assigns.current_scope.user.id == user.id
      assert json_response(conn, 200)["result"]["tools"]
    end
  end

  describe "metadata" do
    test "the protected resource is described at the root and under the endpoint's path" do
      for path <- [
            "/.well-known/oauth-protected-resource",
            "/.well-known/oauth-protected-resource/mcp"
          ] do
        assert build_conn() |> get(path) |> json_response(200) == %{
                 "resource" => url(~p"/mcp"),
                 "authorization_servers" => [FeatherWeb.Endpoint.url()],
                 "bearer_methods_supported" => ["header"]
               }
      end
    end

    test "the authorization server offers the code flow with PKCE for metadata documents" do
      assert build_conn() |> get("/.well-known/oauth-authorization-server") |> json_response(200) ==
               %{
                 "issuer" => FeatherWeb.Endpoint.url(),
                 "authorization_endpoint" => url(~p"/oauth/authorize"),
                 "token_endpoint" => url(~p"/oauth/token"),
                 "response_types_supported" => ["code"],
                 "grant_types_supported" => ["authorization_code", "refresh_token"],
                 "code_challenge_methods_supported" => ["S256"],
                 "token_endpoint_auth_methods_supported" => ["none"],
                 "client_id_metadata_document_supported" => true,
                 "authorization_response_iss_parameter_supported" => true
               }
    end
  end
end
