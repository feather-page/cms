defmodule FeatherWeb.HealthController do
  @moduledoc """
  `GET /up`, the container health check (`HEALTHCHECK` in the Dockerfile): 200
  "ok" when the app runs and the database answers, 503 otherwise. No
  session, no CSRF, excluded from `force_ssl` (`config/prod.exs`).
  """
  use FeatherWeb, :controller

  require Logger

  def show(conn, _params) do
    case Feather.Repo.query("SELECT 1") do
      {:ok, _result} ->
        send_text(conn, :ok, "ok")

      {:error, error} ->
        Logger.warning("Health check failed: #{Exception.message(error)}")
        send_text(conn, :service_unavailable, "database unavailable")
    end
  end

  defp send_text(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end
