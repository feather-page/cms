defmodule FeatherWeb.CodeHighlightController do
  @moduledoc """
  `POST /sites/:site_id/code/highlight` with `{"code": ..., "language": ...}`
  for the editor's code blocks: answers `{"html": ...}` with the token spans
  of the export (`Feather.Highlighting.highlight/3`, same cache), or
  `{"html": null}` for code that stays plain: blank code, a language
  outside the list, or a failing chroma.
  """
  use FeatherWeb, :controller

  alias Feather.Highlighting

  def create(conn, %{"code" => code, "language" => language})
      when is_binary(code) and is_binary(language) do
    case Highlighting.highlight(code, language) do
      {:ok, html} -> json(conn, %{html: html})
      :plain -> json(conn, %{html: nil})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "The code or its language is missing."})
  end
end
