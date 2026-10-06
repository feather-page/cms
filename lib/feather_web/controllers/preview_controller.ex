defmodule FeatherWeb.PreviewController do
  @moduledoc """
  Serves the preview of a site: `/preview/<target public id>/<path>`
  renders the static site's templates live (see
  `Feather.StaticSite.Preview`). Only users who may access the target's
  site get it; for everyone else the target does not exist.
  """

  use FeatherWeb, :controller

  alias Feather.Publishing
  alias Feather.StaticSite.Preview

  def show(conn, %{"target_id" => target_id} = params) do
    with %{} = target <- Publishing.get_preview_target(conn.assigns.current_scope, target_id),
         result when result != :not_found <- Preview.render(target, Map.get(params, "path", [])) do
      respond(conn, result)
    else
      _ -> send_resp(conn, :not_found, "Not Found")
    end
  end

  defp respond(conn, {:html, html}) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(:ok, html)
  end

  defp respond(conn, {:content, content_type, body}) do
    conn
    |> put_resp_content_type(content_type)
    |> send_resp(:ok, body)
  end

  defp respond(conn, {:file, path, content_type}) do
    conn
    |> put_resp_content_type(content_type, nil)
    |> send_file(:ok, path)
  end
end
