defmodule Feather.Fediverse.RateLimit do
  @moduledoc """
  Counts events per key in fixed windows (`hit/3`), in memory: the
  inbox's requests per client and per remote host, and the fetches of a
  remote account's key. Expired windows are swept every minute.

  Started by `Feather.Application`.
  """

  use GenServer

  @table __MODULE__
  @sweep_interval :timer.minutes(1)

  @doc "Starts the counter table."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Counts an event for `key` and returns `:ok` while at most `limit` came
  within the current window of `window_ms` milliseconds,
  `{:error, :rate_limited}` beyond.
  """
  @spec hit(term(), pos_integer(), pos_integer()) :: :ok | {:error, :rate_limited}
  def hit(key, limit, window_ms) do
    {entry, expires_at} = entry(key, window_ms)

    if :ets.update_counter(@table, entry, 1, {entry, 0, expires_at}) <= limit,
      do: :ok,
      else: {:error, :rate_limited}
  end

  @doc "Takes back an event `hit/3` counted for `key` in the current window."
  @spec refund(term(), pos_integer()) :: :ok
  def refund(key, window_ms) do
    {entry, expires_at} = entry(key, window_ms)
    :ets.update_counter(@table, entry, {2, -1, 0, 0}, {entry, 0, expires_at})
    :ok
  end

  defp entry(key, window_ms) do
    window = Integer.floor_div(System.monotonic_time(:millisecond), window_ms)
    {{key, window_ms, window}, (window + 1) * window_ms}
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:"=<", :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)
end
