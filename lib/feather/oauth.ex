defmodule Feather.OAuth do
  @moduledoc """
  The CMS as the OAuth authorization server of its MCP endpoint (ADR 0032).

  A client identifies by its metadata document
  (`Feather.OAuth.ClientMetadata`). `authorization_request/2` checks its
  request to connect, `approve/2` records the member's consent as an
  authorization code bound to the PKCE challenge, and `token/2` exchanges
  that code, or a refresh token, for an access token valid for an hour and
  a refresh token that works once. Each approval creates a
  `Feather.OAuth.ConnectedApp`, which ends when the member revokes it or
  after 90 days unused.

  Codes and tokens are random strings; only their SHA-256 digests are
  stored. The web layer passes in the URL of the MCP endpoint (`resource`)
  that tokens are for.
  """

  import Ecto.Query, warn: false

  alias Feather.Accounts.{Scope, User}
  alias Feather.OAuth.{AuthorizationCode, AuthorizationRequest, ClientMetadata, ConnectedApp}
  alias Feather.Repo

  @code_lifetime_seconds 5 * 60
  @access_token_lifetime_seconds 60 * 60
  @unused_connection_lifetime_days 90
  @last_used_precision_seconds 60
  @code_challenge ~r/\A[A-Za-z0-9_-]{43}\z/

  @type authorization_error ::
          ClientMetadata.error()
          | :invalid_redirect_uri
          | :unsupported_response_type
          | :invalid_request
          | :invalid_target
  @type token_error ::
          :invalid_request | :invalid_grant | :invalid_target | :unsupported_grant_type
  @type tokens :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          expires_in: pos_integer()
        }

  ## Authorization endpoint

  @doc """
  Checks a client's request to connect (the parameters of the authorization
  endpoint) for the MCP endpoint `resource`, after fetching the client's
  metadata document.

  Any error is for the member: the client hears back only once the member
  has decided, so a client cannot use the endpoint to redirect anywhere
  (RFC 9700, 4.11.2).
  """
  @spec authorization_request(map(), String.t()) ::
          {:ok, AuthorizationRequest.t()} | {:error, authorization_error()}
  def authorization_request(params, resource) do
    with {:ok, client} <- ClientMetadata.fetch(params["client_id"]),
         :ok <- ClientMetadata.check_redirect_uri(client, params["redirect_uri"]),
         :ok <- check_authorization_params(params, resource) do
      {:ok,
       %AuthorizationRequest{
         client_id: client.client_id,
         client_name: client.client_name,
         redirect_uri: params["redirect_uri"],
         code_challenge: params["code_challenge"],
         state: if(is_binary(params["state"]), do: params["state"])
       }}
    end
  end

  defp check_authorization_params(params, resource) do
    cond do
      params["response_type"] != "code" -> {:error, :unsupported_response_type}
      params["code_challenge_method"] != "S256" -> {:error, :invalid_request}
      not is_binary(params["code_challenge"]) -> {:error, :invalid_request}
      not Regex.match?(@code_challenge, params["code_challenge"]) -> {:error, :invalid_request}
      params["resource"] != resource -> {:error, :invalid_target}
      true -> :ok
    end
  end

  @doc """
  Records the member's consent to `request` and returns the authorization
  code for the client, which works once within five minutes. Deletes
  expired codes and connections on the way.
  """
  @spec approve(Scope.t(), AuthorizationRequest.t()) :: String.t()
  def approve(%Scope{user: %User{} = user}, %AuthorizationRequest{} = request) do
    now = DateTime.utc_now()
    delete_expired(now)
    code = random_token()

    Repo.insert!(%AuthorizationCode{
      user_id: user.id,
      code_digest: digest(code),
      client_id: request.client_id,
      client_name: request.client_name,
      redirect_uri: request.redirect_uri,
      code_challenge: request.code_challenge,
      expires_at: DateTime.add(now, @code_lifetime_seconds)
    })

    code
  end

  ## Token endpoint

  @doc """
  Answers a token request (the parameters of the token endpoint) for the
  MCP endpoint `resource`: the grant `authorization_code` exchanges a code
  with its PKCE verifier and connects the app, the grant `refresh_token`
  replaces the app's tokens. A code is used up by the first attempt, also
  when that fails.
  """
  @spec token(map(), String.t()) :: {:ok, tokens()} | {:error, token_error()}
  def token(%{"grant_type" => grant_type} = params, resource) do
    if Map.get(params, "resource", resource) == resource,
      do: grant(grant_type, params),
      else: {:error, :invalid_target}
  end

  def token(_params, _resource), do: {:error, :invalid_request}

  defp grant("authorization_code", params) do
    with {:ok, [code, client_id, redirect_uri, verifier]} <-
           fetch_params(params, ~w(code client_id redirect_uri code_verifier)),
         {:ok, authorization_code} <- take_authorization_code(code),
         :ok <- check_authorization_code(authorization_code, client_id, redirect_uri, verifier) do
      connect(authorization_code)
    end
  end

  defp grant("refresh_token", params) do
    with {:ok, [refresh_token]} <- fetch_params(params, ["refresh_token"]),
         {:ok, app} <- fetch_app_by_refresh_token(refresh_token),
         :ok <- check_client(app, params["client_id"]) do
      replace_tokens(app)
    end
  end

  defp grant(_grant_type, _params), do: {:error, :unsupported_grant_type}

  defp fetch_params(params, names) do
    values = Enum.map(names, &params[&1])

    if Enum.all?(values, &(is_binary(&1) and &1 != "")),
      do: {:ok, values},
      else: {:error, :invalid_request}
  end

  defp take_authorization_code(code) do
    Repo.transact(fn ->
      case Repo.get_by(AuthorizationCode, code_digest: digest(code)) do
        nil -> {:error, :invalid_grant}
        authorization_code -> {:ok, Repo.delete!(authorization_code)}
      end
    end)
  end

  defp check_authorization_code(authorization_code, client_id, redirect_uri, verifier) do
    valid? =
      DateTime.after?(authorization_code.expires_at, DateTime.utc_now()) and
        authorization_code.client_id == client_id and
        authorization_code.redirect_uri == redirect_uri and
        Plug.Crypto.secure_compare(s256(verifier), authorization_code.code_challenge)

    if valid?, do: :ok, else: {:error, :invalid_grant}
  end

  defp s256(verifier), do: :sha256 |> :crypto.hash(verifier) |> Base.url_encode64(padding: false)

  defp connect(%AuthorizationCode{} = authorization_code) do
    {tokens, token_fields} = new_tokens(DateTime.utc_now())

    %ConnectedApp{
      user_id: authorization_code.user_id,
      client_id: authorization_code.client_id,
      client_name: authorization_code.client_name
    }
    |> Ecto.Changeset.change(token_fields)
    |> Repo.insert!()

    {:ok, tokens}
  end

  defp fetch_app_by_refresh_token(refresh_token) do
    query =
      from a in active_apps(DateTime.utc_now()),
        where: a.refresh_token_digest == ^digest(refresh_token)

    case Repo.one(query) do
      nil -> {:error, :invalid_grant}
      app -> {:ok, app}
    end
  end

  defp check_client(_app, nil), do: :ok
  defp check_client(%ConnectedApp{client_id: client_id}, client_id), do: :ok
  defp check_client(_app, _client_id), do: {:error, :invalid_grant}

  # Matching the old digest makes a concurrent second use of the same refresh token fail.
  defp replace_tokens(%ConnectedApp{} = app) do
    now = DateTime.utc_now()
    {tokens, token_fields} = new_tokens(now)

    query =
      from a in ConnectedApp,
        where: a.id == ^app.id and a.refresh_token_digest == ^app.refresh_token_digest

    case Repo.update_all(query, set: [updated_at: now] ++ token_fields) do
      {1, _} -> {:ok, tokens}
      {0, _} -> {:error, :invalid_grant}
    end
  end

  defp new_tokens(now) do
    access_token = random_token()
    refresh_token = random_token()

    tokens = %{
      access_token: access_token,
      refresh_token: refresh_token,
      expires_in: @access_token_lifetime_seconds
    }

    token_fields = [
      access_token_digest: digest(access_token),
      access_token_expires_at: DateTime.add(now, @access_token_lifetime_seconds),
      refresh_token_digest: digest(refresh_token),
      last_used_at: now
    ]

    {tokens, token_fields}
  end

  ## MCP endpoint

  @doc """
  Returns the user of a valid access token and records the use of their
  connected app, to the minute.
  """
  @spec authenticate(String.t()) :: {:ok, User.t()} | :error
  def authenticate(access_token) when is_binary(access_token) do
    now = DateTime.utc_now()

    query =
      from a in active_apps(now),
        where:
          a.access_token_digest == ^digest(access_token) and a.access_token_expires_at > ^now,
        preload: :user

    case Repo.one(query) do
      nil ->
        :error

      app ->
        record_use(app, now)
        {:ok, app.user}
    end
  end

  defp record_use(app, now) do
    if DateTime.diff(now, app.last_used_at) >= @last_used_precision_seconds do
      Repo.update_all(from(a in ConnectedApp, where: a.id == ^app.id), set: [last_used_at: now])
    end
  end

  ## Connected apps

  @doc """
  Lists the user's connected apps that have not expired, newest first.
  """
  @spec list_connected_apps(Scope.t()) :: [ConnectedApp.t()]
  def list_connected_apps(%Scope{user: %User{id: user_id}}) do
    Repo.all(
      from a in active_apps(DateTime.utc_now()),
        where: a.user_id == ^user_id,
        order_by: [desc: a.inserted_at]
    )
  end

  @doc """
  Revokes one of the user's connected apps: its tokens stop working at once.
  Any other id changes nothing.
  """
  @spec revoke_connected_app(Scope.t(), term()) :: :ok
  def revoke_connected_app(%Scope{user: %User{id: user_id}}, id) do
    with {:ok, id} <- Ecto.UUID.cast(id) do
      Repo.delete_all(from a in ConnectedApp, where: a.user_id == ^user_id and a.id == ^id)
    end

    :ok
  end

  defp active_apps(now), do: from(a in ConnectedApp, where: a.last_used_at > ^unused_since(now))

  defp delete_expired(now) do
    Repo.delete_all(from c in AuthorizationCode, where: c.expires_at <= ^now)
    Repo.delete_all(from a in ConnectedApp, where: a.last_used_at <= ^unused_since(now))
  end

  defp unused_since(now), do: DateTime.add(now, -@unused_connection_lifetime_days, :day)

  defp random_token, do: 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp digest(token), do: :sha256 |> :crypto.hash(token) |> Base.encode16(case: :lower)
end
