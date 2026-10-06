defmodule FeatherWeb.EditorJsHelpers do
  @moduledoc """
  Builds the Editor.js JSON the editor hook writes into the hidden content
  input, for LiveView tests (Editor.js itself does not run there).
  """

  @doc "Editor.js JSON with one paragraph per text."
  def editor_json(texts) when is_list(texts) do
    Jason.encode!(%{
      "time" => 1,
      "blocks" =>
        Enum.map(texts, fn text -> %{"type" => "paragraph", "data" => %{"text" => text}} end)
    })
  end

  def editor_json(text) when is_binary(text), do: editor_json([text])

  @doc "Editor.js JSON with the given raw blocks."
  def editor_blocks_json(blocks), do: Jason.encode!(%{"time" => 1, "blocks" => blocks})
end
