defmodule Feather.Fediverse.Scheduler do
  @moduledoc """
  Runs the fediverse's periodic work every minute
  (`Feather.Fediverse.run_due/0`): it drops the Timeline posts and the ids
  of received activities older than 30 days, processes the received
  activities that were not processed yet or failed, and delivers the due
  deliveries, the retries of failed ones and those that waited for their
  site's account to go online. One run at a time; the next starts a
  minute after the last ended.

  Started by `Feather.Application`; it does not start (`:ignore`) when
  disabled, as in tests:

      config :feather, Feather.Fediverse.Scheduler, enabled: false

  Options, given to `start_link/1` or in that config (options win):
  `:enabled`, `:run` (a zero-arity function, for tests), `:name`,
  `:interval` and `:initial_delay` in milliseconds (both a minute by
  default). A failing run is logged and the schedule continues.
  """

  use GenServer

  require Logger

  @default_interval :timer.minutes(1)

  @doc false
  def child_spec(opts) do
    %{id: Keyword.get(opts, :name, __MODULE__), start: {__MODULE__, :start_link, [opts]}}
  end

  @doc "Starts the scheduler, or returns `:ignore` when it is disabled."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.merge(Application.get_env(:feather, __MODULE__, []), opts)

    if Keyword.get(opts, :enabled, true) do
      GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
    else
      :ignore
    end
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    schedule(Keyword.get(opts, :initial_delay, interval))

    {:ok, %{interval: interval, run: Keyword.get(opts, :run, &Feather.Fediverse.run_due/0)}}
  end

  @impl true
  def handle_info(:run, state) do
    run(state.run)
    schedule(state.interval)
    {:noreply, state}
  end

  defp schedule(delay), do: Process.send_after(self(), :run, delay)

  defp run(fun) do
    fun.()
  catch
    kind, reason ->
      Logger.error(
        "The fediverse's periodic work failed: " <> Exception.format(kind, reason, __STACKTRACE__)
      )
  end
end
