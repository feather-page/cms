defmodule Feather.Highlighting.Runner do
  @moduledoc """
  Runs a `chroma` command. Implementations return the command's output,
  chroma's message when it fails, or `{:aborted, message}` when chroma is
  missing or timed out.

  Options: `:cd` (the working directory) and `:timeout` (milliseconds; the
  command is killed when it runs longer).
  """

  @doc "Runs `chroma` with the arguments."
  @callback run(args :: [String.t()], opts :: keyword()) ::
              {:ok, String.t()} | {:error, String.t()} | {:aborted, String.t()}
end
