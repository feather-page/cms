defmodule Feather.Content.BlocksType do
  @moduledoc """
  Ecto type for the `content` of posts, pages and projects.

  Casts content in the internal format (a list of blocks, also as a JSON
  string) as well as a ProseMirror document of the admin editor
  (`Feather.Content.ProseMirror`), and always yields normalized blocks, see
  `Feather.Content.Blocks`.
  """

  use Ecto.Type

  alias Feather.Content.{Blocks, ProseMirror}

  @impl true
  def type, do: {:array, :map}

  @impl true
  def cast(nil), do: {:ok, []}
  def cast(blocks) when is_list(blocks), do: {:ok, Blocks.normalize(blocks)}
  def cast(%{"type" => "doc"} = doc), do: {:ok, ProseMirror.from_doc(doc)}

  def cast(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, blocks} when is_list(blocks) -> cast(blocks)
      _other -> {:error, message: "is not valid content"}
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
