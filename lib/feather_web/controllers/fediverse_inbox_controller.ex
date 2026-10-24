defmodule FeatherWeb.FediverseInboxController do
  @moduledoc """
  The inbox of a site's fediverse account at `/fediverse/inbox/<site
  public id>` (ADR 0033), in its own pipeline without session, flash,
  CSRF or user (`FeatherWeb.Plugs.InboxRequest` admits the request).
  `Feather.Fediverse.receive_activity/3` decides; an accepted activity
  gets 202 and is processed afterwards. Answers have no body, so they
  never tell what a fetch found.

  Every other request below `/fediverse/inbox`, whatever path it would
  resolve to, gets 404 here and reaches no other route.
  """
  use FeatherWeb, :controller

  alias Feather.Fediverse

  def create(conn, %{"site_id" => site_id}) do
    request = %{
      method: conn.method,
      path: conn.request_path,
      query: conn.query_string,
      headers: conn.req_headers,
      body: conn.assigns.raw_body
    }

    case Fediverse.receive_activity(site_id, request, conn.assigns.activity) do
      :ok -> send_resp(conn, :accepted, "")
      {:error, reason} -> send_resp(conn, status(reason), "")
    end
  end

  def not_found(conn, _params), do: send_resp(conn, :not_found, "")

  defp status(:not_found), do: :not_found
  defp status(:invalid), do: :bad_request
  defp status(:unauthorized), do: :unauthorized
  defp status(:forbidden), do: :forbidden
  defp status(:rate_limited), do: :too_many_requests
end
