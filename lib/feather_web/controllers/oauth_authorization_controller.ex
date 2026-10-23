defmodule FeatherWeb.OAuthAuthorizationController do
  @moduledoc """
  The authorization endpoint (ADR 0032). A logged-in member sees the
  consent page for a client's request to connect (`new`) and allows or
  denies it (`create`); either way they go back to the client's redirect
  URI, with the issuer (`iss`, RFC 9207). A request that cannot be
  accepted gets an error page instead of a redirect.

  The consent form posts the checked request again, so `create` checks it
  anew, including the client's metadata document.
  """
  use FeatherWeb, :controller

  alias Feather.OAuth
  alias Feather.OAuth.{AuthorizationRequest, ClientMetadata}
  alias FeatherWeb.ContentSecurityPolicy

  plug :put_content_security_policy

  def new(conn, params) do
    case OAuth.authorization_request(params, url(~p"/mcp")) do
      {:ok, request} ->
        conn
        |> put_content_security_policy([origin(request.redirect_uri)])
        |> render(:new,
          request: request,
          request_params: request_params(request),
          redirect_host: URI.parse(request.redirect_uri).host,
          loopback?: ClientMetadata.loopback?(request.redirect_uri),
          page_title: "Connect #{request.client_name}"
        )

      {:error, reason} ->
        refuse(conn, reason)
    end
  end

  def create(conn, params) do
    case OAuth.authorization_request(params, url(~p"/mcp")) do
      {:ok, request} ->
        if params["decision"] == "allow",
          do: send_back(conn, request, code: OAuth.approve(conn.assigns.current_scope, request)),
          else: send_back(conn, request, error: "access_denied")

      {:error, reason} ->
        refuse(conn, reason)
    end
  end

  defp refuse(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> render(:error, message: message(reason), page_title: "The app cannot connect")
  end

  defp send_back(conn, %AuthorizationRequest{} = request, response) do
    query =
      (response ++ [state: request.state, iss: FeatherWeb.Endpoint.url()])
      |> Enum.reject(fn {_name, value} -> is_nil(value) end)
      |> URI.encode_query()

    redirect(conn,
      external: request.redirect_uri |> URI.new!() |> URI.append_query(query) |> URI.to_string()
    )
  end

  defp request_params(%AuthorizationRequest{} = request) do
    Enum.reject(
      [
        response_type: "code",
        client_id: request.client_id,
        redirect_uri: request.redirect_uri,
        code_challenge: request.code_challenge,
        code_challenge_method: "S256",
        resource: url(~p"/mcp"),
        state: request.state
      ],
      fn {_name, value} -> is_nil(value) end
    )
  end

  # Not even our own pages may frame these: a post preview can embed a relative URL.
  defp put_content_security_policy(conn, form_action) do
    policy = ContentSecurityPolicy.header(form_action: form_action, frame_ancestors: "'none'")
    put_resp_header(conn, "content-security-policy", policy)
  end

  defp origin(uri) do
    %URI{scheme: scheme, host: host, port: port} = URI.new!(uri)
    URI.to_string(%URI{scheme: scheme, host: host, port: port})
  end

  defp message(:invalid_client_id),
    do: "The app identifies itself by an address Feather does not accept."

  defp message(:unreachable), do: "The app's description could not be loaded from its address."
  defp message(:invalid_metadata), do: "The app's description is incomplete or invalid."
  defp message(:client_id_mismatch), do: "The app's description belongs to another app."

  defp message(:unsupported_auth_method),
    do: "The app proves who it is in a way Feather does not support."

  defp message(:invalid_redirect_uri),
    do: "The app does not list the address it wants to send you back to."

  defp message(:unsupported_response_type),
    do: "The app asks for a kind of access Feather does not offer."

  defp message(:invalid_request), do: "The app's request to connect is incomplete."

  defp message(:invalid_target), do: "The app asks for access to a server other than Feather."
end
