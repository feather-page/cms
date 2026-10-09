defmodule FeatherWeb.EditorHelpers do
  @moduledoc """
  Builds the params of the editor hook's `sync` event for LiveView tests
  (the editor itself does not run there). The node format is described in
  `Feather.Content.ProseMirror`.
  """

  @doc "A top-level paragraph node with a block id."
  def paragraph_node(id, text) do
    %{"type" => "paragraph", "attrs" => %{"id" => id}, "content" => text_nodes(text)}
  end

  @doc """
  The params of the editor hook's `sync` event building on the record's
  `lock_version`: the block ids in their `order` (nil when unchanged) and
  the changed top-level nodes.
  """
  def sync_params(record, order, blocks) do
    %{"lock_version" => record.lock_version, "order" => order, "blocks" => blocks}
  end

  defp text_nodes(""), do: []
  defp text_nodes(text), do: [%{"type" => "text", "text" => text}]
end
