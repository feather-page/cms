defmodule Feather.Diagrams.Runner do
  @moduledoc """
  Runs a `d2` command. Implementations return the command's output, d2's
  message when it fails, or `{:aborted, message}` when d2 is missing or
  timed out (the source is not to blame, so the failure is not cached).

  Options: `:cd` (the working directory) and `:timeout` (milliseconds; the
  command is killed when it runs longer).
  """

  @doc "Runs `d2` with the arguments."
  @callback run(args :: [String.t()], opts :: keyword()) ::
              {:ok, String.t()} | {:error, String.t()} | {:aborted, String.t()}
end
