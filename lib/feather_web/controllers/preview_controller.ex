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

  @svg_policy "default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; sandbox"

  def show(conn, %{"target_id" => target_id} = params) do
    case Publishing.get_preview_target(conn.assigns.current_scope, target_id) do
      nil -> send_resp(conn, :not_found, "Not Found")
      target -> respond(conn, Preview.render(target, Map.get(params, "path", [])))
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
    |> put_svg_policy(content_type)
    |> put_resp_content_type(content_type, nil)
    |> send_file(:ok, path)
  end

  # A diagram opened on its own must not run scripts or javascript: links in the CMS origin.
  defp put_svg_policy(conn, "image/svg+xml"),
    do: put_resp_header(conn, "content-security-policy", @svg_policy)

  defp put_svg_policy(conn, _content_type), do: conn

  defp send_html(conn, status, html) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, html)
  end
end
