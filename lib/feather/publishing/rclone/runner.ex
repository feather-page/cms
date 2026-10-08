defmodule Feather.Publishing.Rclone.Runner do
  @moduledoc """
  Runs an `rclone` command. Implementations return the command's output
  or an error message.

  Options: `:input` (written to the command's standard input) and
  `:timeout` (milliseconds; the command is killed when it runs longer).
  """

  @doc "Runs `rclone` with the arguments."
  @callback run(args :: [String.t()], opts :: keyword()) ::
              {:ok, String.t()} | {:error, String.t()}
end
