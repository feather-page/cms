defmodule Feather.Diagrams.SystemRunner do
  @moduledoc """
  Runs the `d2` executable found on the `PATH`.

  Options: `:cd` (the working directory), `:timeout` in milliseconds
  (required) kills the command when it runs longer, and `:executable`
  replaces the `d2` on the `PATH` (tests).

  d2 gets an empty environment besides `PATH` and `HOME` (the working
  directory): its own variables (`D2_LAYOUT`, `SCALE`, ...) would change
  diagrams without changing their cache names, and the app's secrets are
  none of its business. On Linux it runs under an address space limit,
  since an icon such as `/dev/zero` makes it read until memory runs out.
  """

  @behaviour Feather.Diagrams.Runner

  alias Feather.SystemCommand

  # Go reserves about 1.2 GiB of address space up front; a large TALA diagram needs ~200 MB more.
  @memory_limit_kib 4 * 1024 * 1024

  @impl true
  def run(args, opts) do
    case Keyword.get_lazy(opts, :executable, fn -> System.find_executable("d2") end) do
      nil -> {:aborted, "d2 is not installed"}
      d2 -> execute(d2, args, opts)
    end
  end

  @doc false
  def command(d2, args, {:unix, :linux}),
    do: {"/bin/sh", ["-c", ~s(ulimit -v #{@memory_limit_kib} && exec "$0" "$@"), d2 | args]}

  def command(d2, args, _os_type), do: {d2, args}

  defp execute(d2, args, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    {executable, args} = command(d2, args, :os.type())
    env = environment(opts[:cd] || System.tmp_dir!())

    case SystemCommand.run(executable, args, cd: opts[:cd], env: env, timeout: timeout) do
      {:exit, 0, output} -> {:ok, output}
      {:exit, _status, output} -> {:error, String.trim(output)}
      {:timeout, _output} -> {:aborted, "d2 timed out after #{div(timeout, 1000)} seconds"}
    end
  end

  defp environment(home) do
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
