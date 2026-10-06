defmodule Feather.StaticSite.Sink do
  @moduledoc """
  Where a static export puts the files it produces (see ADR 0006). A sink
  receives generated content (`write/3`) and copies of existing files
  (`copy/3`); it knows nothing about sites or deployment.

  A sink is a struct whose module implements this behaviour; call it
  through `write/3` and `copy/3` here. Implementations must accept calls
  from several processes at once and guarantee nothing about order.
  Paths are relative (`"posts/abc/index.html"`).
  """

  @type t :: struct()

  @doc "Writes generated content to a path."
  @callback write(sink :: t(), path :: String.t(), content :: iodata()) :: :ok

  @doc "Puts a copy of an existing file at a path."
  @callback copy(sink :: t(), path :: String.t(), opts :: [from: Path.t()]) :: :ok

  @doc "Writes generated content to a path of the sink."
  @spec write(t(), String.t(), iodata()) :: :ok
  def write(%module{} = sink, path, content), do: module.write(sink, path, content)

  @doc "Copies the file `from:` to a path of the sink."
  @spec copy(t(), String.t(), from: Path.t()) :: :ok
  def copy(%module{} = sink, path, opts), do: module.copy(sink, path, opts)
end
