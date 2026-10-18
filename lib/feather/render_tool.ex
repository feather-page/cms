defmodule Feather.RenderTool do
  @moduledoc """
  What the renderers that run an external binary and cache its output under
  the storage root share (`Feather.Diagrams` with d2, `Feather.Highlighting`
  with chroma): runners, the binary's version, a temporary working
  directory, cache names and atomic cache writes.

  A runner is a module with `run/2` or a function taking the argument list
  and the options. It returns the command's output, the binary's message
  when it fails, or `{:aborted, message}` when the binary is missing or
  timed out.
  """

  alias Feather.SystemCommand

  @type result :: {:ok, String.t()} | {:error, String.t()} | {:aborted, String.t()}
  @type runner :: module() | ([String.t()], keyword() -> result())

  @doc "The runner in `opts[:runner]`, else `config :feather, key`, else `default`."
  @spec runner(keyword(), atom(), module()) :: runner()
  def runner(opts, key, default),
    do: Keyword.get_lazy(opts, :runner, fn -> Application.get_env(:feather, key, default) end)

  @doc """
  Runs the runner with the arguments and options. A runner that raises
  (`Port.open` on a binary it may not execute) aborts.
  """
  @spec run(runner(), [String.t()], keyword()) :: result()
  def run(runner, args, opts) do
    call(runner, args, opts)
  rescue
    exception -> {:aborted, Exception.message(exception)}
  end

  defp call(runner, args, opts) when is_function(runner, 2), do: runner.(args, opts)
  defp call(runner, args, opts) when is_atom(runner), do: runner.run(args, opts)

  @doc "The binary's `--version`, asked once per runner module."
  @spec version(runner(), timeout()) :: {:ok, String.t()} | {:error, String.t()}
  def version(runner, timeout) when is_atom(runner) do
    key = {__MODULE__, :version, runner}

    case :persistent_term.get(key, nil) do
      nil ->
        with {:ok, version} <- ask_version(runner, timeout) do
          :persistent_term.put(key, version)
          {:ok, version}
        end

      version ->
        {:ok, version}
    end
  end

  def version(runner, timeout), do: ask_version(runner, timeout)

  defp ask_version(runner, timeout) do
    case run(runner, ["--version"], timeout: timeout) do
      {:ok, output} -> {:ok, String.trim(output)}
      {_error, message} -> {:error, message}
    end
  end

  @doc """
  Calls `fun` with a new empty temporary directory and removes the
  directory afterwards. A `File.Error` becomes `{:error, message}`.
  """
  @spec in_tmp_dir(String.t(), (Path.t() -> result)) :: result | {:error, String.t()}
        when result: term()
  def in_tmp_dir(prefix, fun) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{Feather.PublicId.generate()}")

    try do
      File.mkdir_p!(dir)
      fun.(dir)
    rescue
      exception in File.Error -> {:error, Exception.message(exception)}
    after
      File.rm_rf(dir)
    end
  end

  @doc "A cache name: the hex SHA-256 of the parts."
  @spec hash([iodata()]) :: String.t()
  def hash(parts),
    do: Base.encode16(:crypto.hash(:sha256, Enum.intersperse(parts, 0)), case: :lower)

  @doc """
  Writes `content` to `target` through a partial file and a rename, so
  readers never see half a file.
  """
  @spec write(Path.t(), iodata()) :: :ok | {:error, File.posix()}
  def write(target, content) do
    partial = "#{target}.#{Feather.PublicId.generate()}.partial"

    with :ok <- File.mkdir_p(Path.dirname(target)),
         :ok <- File.write(partial, content),
         :ok <- File.chmod(partial, 0o644),
         :ok <- File.rename(partial, target) do
      :ok
    else
      error ->
        File.rm(partial)
        error
    end
  end

  @doc """
  Runs the executable `name` found on the `PATH` (or `opts[:executable]`)
  through `Feather.SystemCommand`, with an environment holding only `PATH`
  and `HOME` (the working directory): the app's secrets are none of the
  binary's business. `command` turns the executable and arguments into
  the command to spawn.

  Options: `:cd` (the working directory), `:timeout` in milliseconds
  (required) and `:executable`.
  """
  @spec run_executable(String.t(), [String.t()], keyword(), (Path.t(), [String.t()] ->
                                                               {Path.t(), [String.t()]})) ::
          result()
  def run_executable(name, args, opts, command \\ &{&1, &2}) do
    case Keyword.get_lazy(opts, :executable, fn -> System.find_executable(name) end) do
      nil -> {:aborted, "#{name} is not installed"}
      path -> execute(name, command.(path, args), opts)
    end
  end

  defp execute(name, {executable, args}, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    env = minimal_env(opts[:cd] || System.tmp_dir!())

    case SystemCommand.run(executable, args, cd: opts[:cd], env: env, timeout: timeout) do
      {:exit, 0, output} -> {:ok, output}
      {:exit, _status, output} -> {:error, String.trim(output)}
      {:timeout, _output} -> {:aborted, "#{name} timed out after #{div(timeout, 1000)} seconds"}
    end
  end

  defp minimal_env(home) do
    unset =
      for {name, _value} <- System.get_env(),
          name not in ["PATH", "HOME"],
          do: {String.to_charlist(name), false}

    [
      {~c"PATH", String.to_charlist(System.get_env("PATH", ""))},
      {~c"HOME", String.to_charlist(home)} | unset
    ]
  end
end
