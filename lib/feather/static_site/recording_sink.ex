defmodule Feather.StaticSite.RecordingSink do
  @moduledoc """
  A sink that records what an export produced, for tests. Written content
  is kept as a binary; copies are kept as `{:copy, source_path}`, never
  the bytes, so image variants stay out of memory.

  The entries live in an `Agent` linked to the caller; start one with
  `start_link/0` (or `start_supervised!(RecordingSink)` in tests, which
  returns the pid; wrap it with `new/1`).
  """

  @behaviour Feather.StaticSite.Sink

  use Agent

  @enforce_keys [:pid]
  defstruct [:pid]

  @type t :: %__MODULE__{pid: pid()}
  @type entry :: binary() | {:copy, Path.t()}

  @doc "Starts the agent holding the entries."
  def start_link(_opts \\ []), do: Agent.start_link(fn -> %{} end)

  @doc "Starts a recording sink linked to the caller."
  @spec new() :: t()
  def new do
    {:ok, pid} = start_link()
    %__MODULE__{pid: pid}
  end

  @doc "Wraps the pid of a started agent."
  @spec new(pid()) :: t()
  def new(pid) when is_pid(pid), do: %__MODULE__{pid: pid}

  @impl true
  def write(%__MODULE__{pid: pid}, path, content) do
    content = IO.iodata_to_binary(content)
    Agent.update(pid, &Map.put(&1, path, content))
  end

  @impl true
  def copy(%__MODULE__{pid: pid}, path, from: source) do
    Agent.update(pid, &Map.put(&1, path, {:copy, source}))
  end

  @doc "The entry at a path, or nil."
  @spec get(t(), String.t()) :: entry() | nil
  def get(%__MODULE__{pid: pid}, path), do: Agent.get(pid, &Map.get(&1, path))

  @doc "Returns true if something was written or copied to the path."
  @spec exists?(t(), String.t()) :: boolean()
  def exists?(%__MODULE__{pid: pid}, path), do: Agent.get(pid, &Map.has_key?(&1, path))

  @doc "All recorded paths, sorted."
  @spec paths(t()) :: [String.t()]
  def paths(%__MODULE__{pid: pid}), do: Agent.get(pid, &(&1 |> Map.keys() |> Enum.sort()))
end
