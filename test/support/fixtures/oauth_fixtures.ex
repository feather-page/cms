defmodule Feather.OAuthFixtures do
  @moduledoc """
  Test helpers for connecting MCP clients: Claude's client metadata
  document, PKCE pairs and connected apps with their tokens.
  """

  use FeatherWeb, :verified_routes

  import Ecto.Query

  alias Feather.Accounts.{Scope, User}
  alias Feather.OAuth
  alias Feather.OAuth.{AuthorizationRequest, ClientMetadata, ConnectedApp}
  alias Feather.Repo

  @client_id "https://claude.ai/oauth/mcp-oauth-client-metadata"
  @redirect_uri "https://claude.ai/api/mcp/auth_callback"

  def claude_client_id, do: @client_id
  def claude_redirect_uri, do: @redirect_uri

  @doc """
  Serves Claude's client metadata document, merged with `document`, to
  `Feather.OAuth.ClientMetadata`.
  """
  def stub_client_metadata(document \\ %{}) do
    document =
      Map.merge(
        %{
          "client_id" => @client_id,
          "client_name" => "Claude",
          "redirect_uris" => [@redirect_uri]
        },
        document
      )

    Req.Test.stub(ClientMetadata, &Req.Test.json(&1, document))
  end

  def code_verifier, do: 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  def code_challenge(verifier),
    do: :sha256 |> :crypto.hash(verifier) |> Base.url_encode64(padding: false)

  @doc """
  A checked request from Claude to connect, with the challenge of `verifier`.
  """
  def authorization_request_fixture(verifier, attrs \\ %{}) do
    struct!(
      AuthorizationRequest,
      Map.merge(
        %{
          client_id: @client_id,
          client_name: "Claude",
          redirect_uri: @redirect_uri,
          code_challenge: code_challenge(verifier)
        },
        Map.new(attrs)
      )
    )
  end

  @doc """
  Connects Claude (or the client in `attrs`) for `user` through the
  authorization code flow. Returns the tokens with the `connected_app`.
  """
  def connected_app_fixture(%User{} = user, attrs \\ %{}) do
    verifier = code_verifier()
    request = authorization_request_fixture(verifier, attrs)
    code = OAuth.approve(Scope.for_user(user), request)

    {:ok, tokens} =
      OAuth.token(
        %{
          "grant_type" => "authorization_code",
          "code" => code,
          "client_id" => request.client_id,
          "redirect_uri" => request.redirect_uri,
          "code_verifier" => verifier
        },
        url(~p"/mcp")
      )

    app =
      Repo.one!(
        from a in ConnectedApp,
          where: a.user_id == ^user.id,
          order_by: [desc: a.inserted_at],
          limit: 1
      )

    Map.put(tokens, :connected_app, app)
  end

  @doc """
  Moves the app's last use and its tokens `amount` `unit`s into the past.
  """
  def age_connected_app(%ConnectedApp{} = app, amount, unit \\ :day) do
    last_used_at = DateTime.add(DateTime.utc_now(), -amount, unit)

    Repo.update_all(from(a in ConnectedApp, where: a.id == ^app.id),
      set: [
        last_used_at: last_used_at,
        access_token_expires_at: DateTime.add(last_used_at, 1, :hour)
      ]
    )

    Repo.get!(ConnectedApp, app.id)
  end
end
