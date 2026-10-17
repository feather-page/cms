defmodule Feather.Publishing.Rclone.SystemRunner do
  @moduledoc """
  Runs the `rclone` executable found on the `PATH`.

  Options: `:input` is written to the command's standard input (`rclone
  obscure -` reads the password from there, so it never shows up in the
  process list), `:timeout` in milliseconds (default 5 minutes) kills the
  command when it runs longer, and `:executable` replaces the `rclone` on
  the `PATH` (tests).
  """

  @behaviour Feather.Publishing.Rclone.Runner

  alias Feather.SystemCommand

  require Logger

  @default_timeout :timer.minutes(5)

  @impl true
  def run(args, opts \\ []) do
    case Keyword.get_lazy(opts, :executable, fn -> System.find_executable("rclone") end) do
      nil -> {:error, "rclone is not installed"}
      rclone -> execute(rclone, args, opts)
    end
  end

  defp execute(rclone, [command | _] = args, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case SystemCommand.run(rclone, args, input: opts[:input], timeout: timeout) do
      {:exit, 0, output} ->
        # The output of `obscure` and `reveal` is a credential; do not log it.
        if command not in ["obscure", "reveal"],
          do: Logger.info("rclone #{command} finished\n#{output}")

        {:ok, output}

      {:exit, status, output} ->
        {:error, "rclone #{command} failed (exit #{status}): #{String.trim(output)}"}

      {:timeout, output} ->
        Logger.warning("rclone #{command} timed out\n#{output}")
        {:error, "rclone #{command} timed out after #{div(timeout, 1000)} seconds"}
    end
  end
end
