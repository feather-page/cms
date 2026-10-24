defmodule Feather.Fediverse.Limiter do
  @moduledoc """
  Caps the requests to fediverse servers that run at once (`run/3`), in
  two pools: the fetches of keys, actors and WebFinger that the inbox
  makes to check a signature (`:inbox`, at most 4 in all and 2 per remote
  host), and all others (`:general`, at most 10 and 3), so that forged
  activities hold up no delivery, picture or follow. A request waits for
  a free slot of its pool, in the order they came, up to its timeout and
  then fails with `{:error, :busy}`. The slot of a request whose process
  dies is freed.

  Started by `Feather.Application`, one per pool (`:pool`); tests start
  their own with `:name`, `:max_total` and `:max_per_host`.
  """

  use GenServer

  @pools %{general: {10, 3}, inbox: {4, 2}}
  @default_timeout 10_000

  @type pool :: :general | :inbox

  @doc false
  def child_spec(opts) do
    %{id: name(opts), start: {__MODULE__, :start_link, [opts]}}
  end

  @doc "Starts the limiter of a pool (`:pool`, `:general` by default)."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: name(opts))

  defp name(opts), do: Keyword.get_lazy(opts, :name, fn -> pool_name(pool(opts)) end)

  defp pool(opts), do: Keyword.get(opts, :pool, :general)

  defp pool_name(:general), do: __MODULE__
  defp pool_name(:inbox), do: __MODULE__.Inbox

  @doc """
  Runs `fun` in a slot for requests to `host` and returns its result, or
  `{:error, :busy}` when no slot came free within `:timeout` (10 seconds
  by default). `:pool` names the pool, `:server` another limiter.
  """
  @spec run(String.t(), (-> result), keyword()) :: result | {:error, :busy} when result: var
  def run(host, fun, opts \\ []) do
    server = Keyword.get_lazy(opts, :server, fn -> pool_name(pool(opts)) end)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case GenServer.call(server, {:acquire, host, timeout}, :infinity) do
      {:ok, ref} ->
        try do
          fun.()
        after
          GenServer.cast(server, {:release, ref})
        end

      :busy ->
        {:error, :busy}
    end
  end

  @impl true
  def init(opts) do
    {max_total, max_per_host} = Map.fetch!(@pools, pool(opts))

    {:ok,
     %{
       max_total: Keyword.get(opts, :max_total, max_total),
       max_per_host: Keyword.get(opts, :max_per_host, max_per_host),
       running: %{},
       waiting: []
     }}
  end

  @impl true
  def handle_call({:acquire, host, timeout}, {pid, _tag} = from, state) do
    ref = Process.monitor(pid)

    if free?(state, host) do
      {:reply, {:ok, ref}, put_running(state, ref, host)}
    else
      timer = Process.send_after(self(), {:expire, ref}, timeout)
      {:noreply, %{state | waiting: [{ref, from, host, timer} | state.waiting]}}
    end
  end

  @impl true
  def handle_cast({:release, ref}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state |> drop_running(ref) |> grant_waiting()}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case List.keytake(state.waiting, ref, 0) do
      {{^ref, _from, _host, timer}, waiting} ->
        Process.cancel_timer(timer)
        {:noreply, %{state | waiting: waiting}}

      nil ->
        {:noreply, state |> drop_running(ref) |> grant_waiting()}
    end
  end

  def handle_info({:expire, ref}, state) do
    case List.keytake(state.waiting, ref, 0) do
      {{^ref, from, _host, _timer}, waiting} ->
        Process.demonitor(ref, [:flush])
        GenServer.reply(from, :busy)
        {:noreply, %{state | waiting: waiting}}

      nil ->
        {:noreply, state}
    end
  end

  defp free?(state, host) do
    map_size(state.running) < state.max_total and
      Enum.count(state.running, fn {_ref, running_host} -> running_host == host end) <
        state.max_per_host
  end

  defp put_running(state, ref, host), do: %{state | running: Map.put(state.running, ref, host)}
  defp drop_running(state, ref), do: %{state | running: Map.delete(state.running, ref)}

  # The waiting requests are kept newest first; the oldest get a slot first.
  defp grant_waiting(state) do
    state.waiting
    |> Enum.reverse()
    |> Enum.reduce(%{state | waiting: []}, fn {ref, from, host, timer} = waiter, state ->
      if free?(state, host) do
        Process.cancel_timer(timer)
        GenServer.reply(from, {:ok, ref})
        put_running(state, ref, host)
      else
        %{state | waiting: [waiter | state.waiting]}
      end
    end)
  end
end
