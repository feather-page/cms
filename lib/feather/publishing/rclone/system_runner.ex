defmodule Feather.Publishing.Rclone.SystemRunner do
  @moduledoc """
  Runs the `rclone` executable found on the `PATH`.
  """

  @behaviour Feather.Publishing.Rclone.Runner

  require Logger

  @impl true
  def run([command | _] = args) do
    case System.find_executable("rclone") do
      nil ->
        {:error, "rclone is not installed"}

      rclone ->
        case System.cmd(rclone, args, stderr_to_stdout: true) do
          {output, 0} ->
            # The output of `obscure` is a credential; do not log it.
            if command != "obscure", do: Logger.info("rclone #{command} finished\n#{output}")
            {:ok, output}

          {output, status} ->
            {:error, "rclone #{command} failed (exit #{status}): #{String.trim(output)}"}
        end
    end
  end
end
