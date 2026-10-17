defmodule Feather.SystemCommand do
  @moduledoc """
  Runs an executable through a port and collects its output, standard
  output and standard error together. A command that runs longer than its
  timeout is killed.
  """

  @type result :: {:exit, non_neg_integer(), String.t()} | {:timeout, String.t()}

  @doc """
  Runs `executable` with `args`.

  ## Options

    * `:timeout` - milliseconds (required)
    * `:input` - written to the command's standard input
    * `:cd` - the working directory
    * `:env` - environment changes as for `Port.open/2`
  """
  @spec run(Path.t(), [String.t()], keyword()) :: result()
  def run(executable, args, opts) do
    deadline = System.monotonic_time(:millisecond) + Keyword.fetch!(opts, :timeout)
    port = Port.open({:spawn_executable, executable}, port_options(args, opts))

    if input = opts[:input], do: Port.command(port, input)

    case collect(port, [], deadline) do
      {:timeout, _output} = timeout ->
        kill(port)
        timeout

      exit ->
        exit
    end
  end

  defp port_options(args, opts) do
    options = [:binary, :exit_status, :stderr_to_stdout, :hide, args: args, env: opts[:env] || []]
    if cd = opts[:cd], do: [{:cd, cd} | options], else: options
  end

  defp collect(port, acc, deadline) do
    receive do
      {^port, {:data, data}} ->
        collect(port, [acc | data], deadline)

      {^port, {:exit_status, status}} ->
        {:exit, status, IO.iodata_to_binary(acc)}
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        {:timeout, IO.iodata_to_binary(acc)}
    end
  end

  defp kill(port) do
    case Port.info(port, :os_pid) do
      # The shell's builtin kill: the release image has no kill executable.
      {:os_pid, os_pid} -> System.cmd("/bin/sh", ["-c", "kill -9 #{os_pid}"])
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
