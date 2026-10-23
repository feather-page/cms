defmodule Feather.OAuthTest do
  use Feather.DataCase

  alias Feather.OAuth
  alias Feather.OAuth.{AuthorizationCode, AuthorizationRequest, ConnectedApp}

  @resource "http://localhost:4002/mcp"

  setup do
    stub_client_metadata()
    verifier = code_verifier()
    %{scope: user_scope_fixture(), verifier: verifier}
  end

  defp request_params(verifier, overrides \\ %{}) do
    Map.merge(
      %{
        "response_type" => "code",
        "client_id" => claude_client_id(),
        "redirect_uri" => claude_redirect_uri(),
        "code_challenge" => code_challenge(verifier),
        "code_challenge_method" => "S256",
        "resource" => @resource,
        "state" => "af0ifjsldkj"
      },
      overrides
    )
  end

  defp code_params(code, verifier, overrides \\ %{}) do
    Map.merge(
      %{
        "grant_type" => "authorization_code",
        "code" => code,
        "client_id" => claude_client_id(),
        "redirect_uri" => claude_redirect_uri(),
        "code_verifier" => verifier,
        "resource" => @resource
      },
      overrides
    )
  end

  defp refresh_params(refresh_token, overrides \\ %{}) do
    Map.merge(
      %{
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token,
        "client_id" => claude_client_id()
      },
      overrides
    )
  end

  defp approve(scope, verifier) do
    OAuth.approve(scope, authorization_request_fixture(verifier))
  end

  describe "authorization_request/2" do
    test "returns the request with the name from the client's metadata", %{verifier: verifier} do
      assert OAuth.authorization_request(request_params(verifier), @resource) ==
               {:ok,
                %AuthorizationRequest{
                  client_id: claude_client_id(),
                  client_name: "Claude",
                  redirect_uri: claude_redirect_uri(),
                  code_challenge: code_challenge(verifier),
                  state: "af0ifjsldkj"
                }}
    end

    test "refuses an untrusted client or redirect URI without a request to send back", %{
      verifier: verifier
    } do
      assert OAuth.authorization_request(
               request_params(verifier, %{"client_id" => "http://claude.ai/metadata"}),
               @resource
             ) == {:error, :invalid_client_id}

      assert OAuth.authorization_request(
               request_params(verifier, %{"redirect_uri" => "https://evil.example/callback"}),
               @resource
             ) == {:error, :invalid_redirect_uri}

      stub_client_metadata(%{"client_id" => "https://evil.example/metadata"})

      assert OAuth.authorization_request(request_params(verifier), @resource) ==
               {:error, :client_id_mismatch}
    end

    test "refuses a request without PKCE, for another resource or response type", %{
      verifier: verifier
    } do
      for {overrides, error} <- [
            {%{"response_type" => "token"}, :unsupported_response_type},
            {%{"code_challenge_method" => "plain"}, :invalid_request},
            {%{"code_challenge_method" => nil}, :invalid_request},
            {%{"code_challenge" => nil}, :invalid_request},
            {%{"code_challenge" => "too-short"}, :invalid_request},
            {%{"resource" => "https://other.example/mcp"}, :invalid_target},
            {%{"resource" => nil}, :invalid_target}
          ] do
        assert OAuth.authorization_request(request_params(verifier, overrides), @resource) ==
                 {:error, error}
      end
    end
  end

  describe "approve/2" do
    test "stores only the code's digest, valid for five minutes", %{
      scope: scope,
      verifier: verifier
    } do
      code = approve(scope, verifier)

      assert [stored] = Repo.all(AuthorizationCode)
      refute stored.code_digest =~ code
      assert stored.user_id == scope.user.id
      assert stored.client_name == "Claude"
      assert_in_delta DateTime.diff(stored.expires_at, DateTime.utc_now()), 300, 2
    end

    test "deletes expired codes", %{scope: scope, verifier: verifier} do
      approve(scope, verifier)
      Repo.update_all(AuthorizationCode, set: [expires_at: DateTime.add(DateTime.utc_now(), -1)])

      approve(scope, verifier)

      assert Repo.aggregate(AuthorizationCode, :count) == 1
    end
  end

  describe "token/2 with an authorization code" do
    test "connects the app and returns tokens for an hour", %{scope: scope, verifier: verifier} do
      code = approve(scope, verifier)

      assert {:ok, %{access_token: access_token, refresh_token: refresh_token, expires_in: 3600}} =
               OAuth.token(code_params(code, verifier), @resource)

      assert [%ConnectedApp{client_name: "Claude"} = app] = OAuth.list_connected_apps(scope)
      assert app.client_id == claude_client_id()
      refute app.access_token_digest =~ access_token
      refute app.refresh_token_digest =~ refresh_token
      assert {:ok, user} = OAuth.authenticate(access_token)
      assert user.id == scope.user.id
    end

    test "accepts a request without a resource", %{scope: scope, verifier: verifier} do
      code = approve(scope, verifier)

      assert {:ok, _tokens} =
               OAuth.token(Map.delete(code_params(code, verifier), "resource"), @resource)
    end

    test "works once", %{scope: scope, verifier: verifier} do
      code = approve(scope, verifier)
      assert {:ok, _tokens} = OAuth.token(code_params(code, verifier), @resource)

      assert OAuth.token(code_params(code, verifier), @resource) == {:error, :invalid_grant}
    end

    test "refuses a wrong verifier, client or redirect URI and burns the code", %{
      scope: scope,
      verifier: verifier
    } do
      for overrides <- [
            %{"code_verifier" => code_verifier()},
            %{"client_id" => "https://other.example/metadata"},
            %{"redirect_uri" => "https://claude.ai/api/mcp/other_callback"}
          ] do
        code = approve(scope, verifier)

        assert OAuth.token(code_params(code, verifier, overrides), @resource) ==
                 {:error, :invalid_grant}

        assert OAuth.token(code_params(code, verifier), @resource) == {:error, :invalid_grant}
      end

      assert OAuth.list_connected_apps(scope) == []
    end

    test "refuses an expired code", %{scope: scope, verifier: verifier} do
      code = approve(scope, verifier)
      Repo.update_all(AuthorizationCode, set: [expires_at: DateTime.add(DateTime.utc_now(), -1)])

      assert OAuth.token(code_params(code, verifier), @resource) == {:error, :invalid_grant}
    end

    test "refuses a resource other than the MCP endpoint", %{scope: scope, verifier: verifier} do
      code = approve(scope, verifier)

      assert OAuth.token(
               code_params(code, verifier, %{"resource" => "https://other.example/mcp"}),
               @resource
             ) == {:error, :invalid_target}
    end

    test "refuses incomplete requests and unknown grants", %{scope: scope, verifier: verifier} do
      code = approve(scope, verifier)

      for name <- ~w(code client_id redirect_uri code_verifier) do
        assert OAuth.token(Map.delete(code_params(code, verifier), name), @resource) ==
                 {:error, :invalid_request}
      end

      assert OAuth.token(%{}, @resource) == {:error, :invalid_request}

      assert OAuth.token(%{"grant_type" => "client_credentials"}, @resource) ==
               {:error, :unsupported_grant_type}
    end
  end

  describe "token/2 with a refresh token" do
    test "replaces both tokens, and the refresh token works once", %{scope: scope} do
      %{access_token: old_access_token, refresh_token: refresh_token} =
        connected_app_fixture(scope.user)

      assert {:ok, %{access_token: access_token, refresh_token: new_refresh_token}} =
               OAuth.token(refresh_params(refresh_token), @resource)

      assert OAuth.token(refresh_params(refresh_token), @resource) == {:error, :invalid_grant}
      assert OAuth.authenticate(old_access_token) == :error
      assert {:ok, _user} = OAuth.authenticate(access_token)
      assert {:ok, _tokens} = OAuth.token(refresh_params(new_refresh_token), @resource)
    end

    test "counts as a use of the app", %{scope: scope} do
      %{connected_app: app, refresh_token: refresh_token} = connected_app_fixture(scope.user)
      age_connected_app(app, 30)

      assert {:ok, _tokens} =
               OAuth.token(Map.delete(refresh_params(refresh_token), "client_id"), @resource)

      assert_in_delta DateTime.diff(
                        Repo.get!(ConnectedApp, app.id).last_used_at,
                        DateTime.utc_now()
                      ),
                      0,
                      2
    end

    test "refuses another client, another resource and an expired connection", %{scope: scope} do
      %{connected_app: app, refresh_token: refresh_token} = connected_app_fixture(scope.user)

      assert OAuth.token(
               refresh_params(refresh_token, %{"client_id" => "https://other.example/metadata"}),
               @resource
             ) == {:error, :invalid_grant}

      assert OAuth.token(
               refresh_params(refresh_token, %{"resource" => "https://other.example/mcp"}),
               @resource
             ) == {:error, :invalid_target}

      age_connected_app(app, 90)
      assert OAuth.token(refresh_params(refresh_token), @resource) == {:error, :invalid_grant}
    end

    test "refuses an unknown or missing refresh token" do
      assert OAuth.token(refresh_params("unknown"), @resource) == {:error, :invalid_grant}

      assert OAuth.token(Map.delete(refresh_params("x"), "refresh_token"), @resource) ==
               {:error, :invalid_request}
    end
  end

  describe "authenticate/1" do
    test "records the use at most once a minute", %{scope: scope} do
      %{connected_app: app, access_token: access_token} = connected_app_fixture(scope.user)

      app = age_connected_app(app, 30, :second)
      assert {:ok, _user} = OAuth.authenticate(access_token)
      assert Repo.get!(ConnectedApp, app.id).last_used_at == app.last_used_at

      age_connected_app(app, 2, :minute)
      assert {:ok, _user} = OAuth.authenticate(access_token)

      assert_in_delta DateTime.diff(
                        Repo.get!(ConnectedApp, app.id).last_used_at,
                        DateTime.utc_now()
                      ),
                      0,
                      2
    end

    test "refuses unknown and expired access tokens", %{scope: scope} do
      %{connected_app: app, access_token: access_token} = connected_app_fixture(scope.user)

      assert OAuth.authenticate("unknown") == :error

      Repo.update_all(from(a in ConnectedApp, where: a.id == ^app.id),
        set: [access_token_expires_at: DateTime.add(DateTime.utc_now(), -1)]
      )

      assert OAuth.authenticate(access_token) == :error
    end

    test "refuses the access token of a connection unused for 90 days", %{scope: scope} do
      %{connected_app: app, access_token: access_token} = connected_app_fixture(scope.user)

      Repo.update_all(from(a in ConnectedApp, where: a.id == ^app.id),
        set: [last_used_at: DateTime.add(DateTime.utc_now(), -90, :day)]
      )

      assert OAuth.authenticate(access_token) == :error
    end
  end

  describe "connected apps" do
    test "lists the user's active apps, newest first", %{scope: scope} do
      %{connected_app: first} = connected_app_fixture(scope.user)
      %{connected_app: second} = connected_app_fixture(scope.user, client_name: "Claude Code")
      %{connected_app: expired} = connected_app_fixture(scope.user)
      age_connected_app(expired, 91)
      connected_app_fixture(user_fixture())

      assert scope |> OAuth.list_connected_apps() |> Enum.map(& &1.id) == [second.id, first.id]
    end

    test "approving deletes connections unused for 90 days", %{scope: scope, verifier: verifier} do
      %{connected_app: expired} = connected_app_fixture(scope.user)
      age_connected_app(expired, 91)

      approve(scope, verifier)

      refute Repo.get(ConnectedApp, expired.id)
    end

    test "revoking ends the app's access at once", %{scope: scope} do
      %{connected_app: app, access_token: access_token, refresh_token: refresh_token} =
        connected_app_fixture(scope.user)

      assert OAuth.revoke_connected_app(scope, app.id) == :ok

      assert OAuth.list_connected_apps(scope) == []
      assert OAuth.authenticate(access_token) == :error
      assert OAuth.token(refresh_params(refresh_token), @resource) == {:error, :invalid_grant}
    end

    test "a user cannot revoke another user's app", %{scope: scope} do
      %{connected_app: app, access_token: access_token} = connected_app_fixture(user_fixture())

      assert OAuth.revoke_connected_app(scope, app.id) == :ok

      assert {:ok, _user} = OAuth.authenticate(access_token)
    end

    test "revoking an id that is not a UUID changes nothing", %{scope: scope} do
      %{access_token: access_token} = connected_app_fixture(scope.user)

      for id <- ["not-a-uuid", 7, %{}] do
        assert OAuth.revoke_connected_app(scope, id) == :ok
      end

      assert {:ok, _user} = OAuth.authenticate(access_token)
    end
  end
end
