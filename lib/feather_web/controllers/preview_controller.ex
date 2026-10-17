defmodule FeatherWeb.PreviewController do
  @moduledoc """
  Serves the preview of a site: `/preview/<site public id>/<path>` renders
  the static site's templates live (see `Feather.StaticSite.Preview`). Only
  users who may access the site get it; for everyone else it does not
  exist.
  """

  use FeatherWeb, :controller

  alias Feather.Sites
  alias Feather.StaticSite.Preview

  def show(conn, %{"site_id" => site_id} = params) do
    case Sites.get_site(conn.assigns.current_scope, site_id) do
      nil -> send_resp(conn, :not_found, "Not Found")
      site -> respond(conn, Preview.render(site, Map.get(params, "path", [])))
    end
  end

  defp respond(conn, {:html, html}), do: send_html(conn, :ok, html)
  defp respond(conn, {:not_found, html}), do: send_html(conn, :not_found, html)

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

  defp send_html(conn, status, html) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, html)
  end
end
