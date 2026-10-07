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

    port =
      Port.open({:spawn_executable, rclone}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        :hide,
        args: args
      ])

    if input = opts[:input], do: Port.command(port, input)

    case collect(port, [], System.monotonic_time(:millisecond) + timeout) do
      {:exit, output, 0} ->
        # The output of `obscure` and `reveal` is a credential; do not log it.
        if command not in ["obscure", "reveal"],
          do: Logger.info("rclone #{command} finished\n#{output}")

        {:ok, output}

      {:exit, output, status} ->
        {:error, "rclone #{command} failed (exit #{status}): #{String.trim(output)}"}

      {:timeout, output} ->
        kill(port)
        Logger.warning("rclone #{command} timed out\n#{output}")
        {:error, "rclone #{command} timed out after #{div(timeout, 1000)} seconds"}
    end
  end

  defp collect(port, acc, deadline) do
    receive do
      {^port, {:data, data}} ->
        collect(port, [acc | data], deadline)

      {^port, {:exit_status, status}} ->
        {:exit, IO.iodata_to_binary(acc), status}
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        {:timeout, IO.iodata_to_binary(acc)}
    end
  end

  defp kill(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, os_pid} -> System.cmd("kill", ["-KILL", Integer.to_string(os_pid)])
      nil -> :ok
    end

    Port.close(port)
  rescue
    ArgumentError -> :ok
  after
    flush(port)
  end

  defp flush(port) do
    receive do
      {^port, _message} -> flush(port)
    after
      0 -> :ok
    end
  end
end
