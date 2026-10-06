defmodule Feather.StaticSite.FileSink do
  @moduledoc """
  A sink backed by a fresh temporary directory inside a parent directory,
  so that it shares a filesystem with the export's destination and can be
  moved there cheaply. `dir/1` and `discard/1` are specific to this sink
  and not part of the `Feather.StaticSite.Sink` contract.
  """

  @behaviour Feather.StaticSite.Sink

  @enforce_keys [:dir]
  defstruct [:dir]

  @type t :: %__MODULE__{dir: Path.t()}

  @doc "Creates a sink in a new directory `export-<random>` inside `parent_dir`."
  @spec new(Path.t()) :: t()
  def new(parent_dir) do
    dir = Path.join(parent_dir, "export-#{Feather.PublicId.generate()}")
    File.mkdir_p!(dir)
    %__MODULE__{dir: dir}
  end

  @doc "The directory holding the files."
  @spec dir(t()) :: Path.t()
  def dir(%__MODULE__{dir: dir}), do: dir

  @doc "Removes the directory and everything in it (if it still exists)."
  @spec discard(t()) :: :ok
  def discard(%__MODULE__{dir: dir}) do
    File.rm_rf!(dir)
    :ok
  end

  @impl true
  def write(%__MODULE__{} = sink, path, content) do
    File.write!(prepare(sink, path), content)
  end

  @impl true
  def copy(%__MODULE__{} = sink, path, from: source) do
    File.cp!(source, prepare(sink, path))
  end

  defp prepare(%__MODULE__{dir: dir}, path) do
    full_path = Path.join(dir, Path.relative(path))

    unless contained?(full_path, dir) do
      raise ArgumentError, "path #{inspect(path)} leaves the sink directory"
    end

    File.mkdir_p!(Path.dirname(full_path))
    full_path
  end

  defp contained?(path, dir) do
    String.starts_with?(Path.expand(path), Path.expand(dir) <> "/")
  end
end
