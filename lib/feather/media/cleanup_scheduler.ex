defmodule Feather.Media.CleanupScheduler do
  @moduledoc """
  Runs `Feather.Media.cleanup_orphaned_images/1` once a day, the first time
  a few minutes after boot.

  Started by `Feather.Application`; it does not start (`:ignore`) when
  disabled, as in tests:

      config :feather, Feather.Media.CleanupScheduler, enabled: false

  Options, given to `start_link/1` or in that config (options win):
  `:enabled`, `:initial_delay` and `:interval` in milliseconds, `:cleanup`
  (a zero-arity function, for tests) and `:name`. A failing run is logged
  and the schedule continues.
  """

  use GenServer

  require Logger

  @default_initial_delay :timer.minutes(5)
  @default_interval :timer.hours(24)

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
    state = %{
      interval: Keyword.get(opts, :interval, @default_interval),
      cleanup: Keyword.get(opts, :cleanup, &Feather.Media.cleanup_orphaned_images/0)
    }

    schedule(Keyword.get(opts, :initial_delay, @default_initial_delay))
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    run(state.cleanup)
    schedule(state.interval)
    {:noreply, state}
  end

  defp schedule(delay), do: Process.send_after(self(), :run, delay)

  defp run(cleanup) do
    case cleanup.() do
      {:ok, %{unreferenced: unreferenced, unused: unused}} ->
        Logger.info(
          "Image cleanup deleted #{length(unreferenced)} unreferenced and " <>
            "#{length(unused)} no longer embedded images"
        )

      other ->
        Logger.warning("Image cleanup failed: #{inspect(other)}")
    end
  rescue
    exception ->
      Logger.error(
        "Image cleanup crashed: " <> Exception.format(:error, exception, __STACKTRACE__)
      )
  end
end
