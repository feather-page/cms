defmodule FeatherWeb.DiagramPreviewController do
  @moduledoc """
  `POST /sites/:site_id/diagrams/preview` with `{"code": "<D2 source>"}`
  for the editor's diagram block: answers `{"svg": ...}`, rendered with the
  export's options (`Feather.Diagrams.render_svg/2`), or `{"error": ...}`
  with d2's message (422).
  """
  use FeatherWeb, :controller

  alias Feather.Diagrams

  def create(conn, %{"code" => code}) when is_binary(code) do
    case Diagrams.render_svg(code) do
      {:ok, svg} -> json(conn, %{svg: svg})
      {:error, message} -> conn |> put_status(:unprocessable_entity) |> json(%{error: message})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "The D2 source is missing."})
  end
end
