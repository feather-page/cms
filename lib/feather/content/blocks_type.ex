defmodule Feather.Content.BlocksType do
  @moduledoc """
  Ecto type for the `content` of posts, pages and projects.

  Casts content in the internal format (a list of blocks) as well as
  Editor.js output (a map with `"blocks"` or its JSON string) and always
  yields normalized blocks, see `Feather.Content.Blocks`.
  """

  use Ecto.Type

  alias Feather.Content.Blocks

  @impl true
  def type, do: {:array, :map}

  @impl true
  def cast(nil), do: {:ok, []}
  def cast(blocks) when is_list(blocks), do: {:ok, Blocks.normalize(blocks)}
  def cast(%{} = editor_js), do: {:ok, Blocks.from_editor_js(editor_js)}

  def cast(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, blocks} when is_list(blocks) -> {:ok, Blocks.normalize(blocks)}
      {:ok, %{} = editor_js} -> {:ok, Blocks.from_editor_js(editor_js)}
      _ -> {:error, message: "is not valid content"}
    end
  end

  def cast(_other), do: :error

  @impl true
  def load(nil), do: {:ok, []}
  def load(blocks) when is_list(blocks), do: {:ok, blocks}
  def load(_other), do: :error

  @impl true
  def dump(blocks) when is_list(blocks), do: {:ok, blocks}
  def dump(nil), do: {:ok, []}
  def dump(_other), do: :error
end
