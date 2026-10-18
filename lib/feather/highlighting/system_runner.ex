defmodule Feather.Highlighting.SystemRunner do
  @moduledoc """
  Runs the `chroma` executable found on the `PATH` (see
  `Feather.RenderTool.run_executable/4`).

  Options: `:cd` (the working directory), `:timeout` in milliseconds
  (required) kills the command when it runs longer, and `:executable`
  replaces the `chroma` on the `PATH` (tests).
  """

  @behaviour Feather.Highlighting.Runner

  alias Feather.RenderTool

  @impl true
  def run(args, opts), do: RenderTool.run_executable("chroma", args, opts)
end
