defmodule Feather.Publishing.Rclone.Runner do
  @moduledoc """
  Runs an `rclone` command. Implementations return the command's output
  or an error message.
  """

  @doc "Runs `rclone` with the arguments."
  @callback run(args :: [String.t()]) :: {:ok, String.t()} | {:error, String.t()}
end
