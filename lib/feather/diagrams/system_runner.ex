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

  alias Feather.RenderTool

  # Go reserves about 1.2 GiB of address space up front; a large TALA diagram needs ~200 MB more.
  @memory_limit_kib 4 * 1024 * 1024

  @impl true
  def run(args, opts),
    do: RenderTool.run_executable("d2", args, opts, &command(&1, &2, :os.type()))

  @doc false
  def command(d2, args, {:unix, :linux}),
    do: {"/bin/sh", ["-c", ~s(ulimit -v #{@memory_limit_kib} && exec "$0" "$@"), d2 | args]}

  def command(d2, args, _os_type), do: {d2, args}
end
