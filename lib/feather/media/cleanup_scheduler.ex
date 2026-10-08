defmodule Feather.Media.CleanupScheduler do
  @moduledoc """
  Runs `Feather.Media.cleanup_orphaned_images/1` every day at 03:00 UTC
  (like the Rails app's recurring job), not after boot: a deploy or restart
  never triggers a cleanup.

  Started by `Feather.Application`; it does not start (`:ignore`) when
  disabled, as in tests:

      config :feather, Feather.Media.CleanupScheduler, enabled: false

  Options, given to `start_link/1` or in that config (options win):
  `:enabled`, `:at` (the UTC `Time` of the daily run), `:cleanup` (a
  zero-arity function, for tests) and `:name`. Tests may also give
  `:initial_delay` and `:interval` in milliseconds instead of the daily
  time. A failing run is logged and the schedule continues.
  """

  use GenServer

  require Logger

  @default_at ~T[03:00:00]

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
      at: Keyword.get(opts, :at, @default_at),
      interval: Keyword.get(opts, :interval),
      cleanup: Keyword.get(opts, :cleanup, &Feather.Media.cleanup_orphaned_images/0)
    }

    schedule(Keyword.get_lazy(opts, :initial_delay, fn -> next_delay(state) end))
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    run(state.cleanup)
    schedule(next_delay(state))
    {:noreply, state}
  end

  defp next_delay(%{interval: interval}) when is_integer(interval), do: interval
  defp next_delay(%{at: at}), do: ms_until(at, DateTime.utc_now())

  @doc """
  Milliseconds from `now` until the next time of day `at` (UTC); a full day
  when `now` is exactly at it.
  """
  @spec ms_until(Time.t(), DateTime.t()) :: pos_integer()
  def ms_until(%Time{} = at, %DateTime{} = now) do
    today = DateTime.new!(DateTime.to_date(now), at, "Etc/UTC")
    next = if DateTime.compare(today, now) == :gt, do: today, else: DateTime.add(today, 1, :day)
    DateTime.diff(next, now, :millisecond)
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
