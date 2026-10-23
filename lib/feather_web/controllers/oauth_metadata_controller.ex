defmodule FeatherWeb.OAuthMetadataController do
  @moduledoc """
  The metadata MCP clients discover the CMS by (ADR 0032): the MCP endpoint
  as protected resource (RFC 9728) and the CMS as its authorization server
  (RFC 8414), which issues tokens by the authorization code flow with PKCE
  to clients that identify by a metadata document.
  """
  use FeatherWeb, :controller

  def protected_resource(conn, _params) do
    json(conn, %{
      resource: url(~p"/mcp"),
      authorization_servers: [FeatherWeb.Endpoint.url()],
      bearer_methods_supported: ["header"]
    })
  end

  def authorization_server(conn, _params) do
    json(conn, %{
      issuer: FeatherWeb.Endpoint.url(),
      authorization_endpoint: url(~p"/oauth/authorize"),
      token_endpoint: url(~p"/oauth/token"),
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code", "refresh_token"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      client_id_metadata_document_supported: true,
      authorization_response_iss_parameter_supported: true
    })
  end
end
