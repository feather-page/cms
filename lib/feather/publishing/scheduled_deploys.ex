defmodule Feather.Publishing.ScheduledDeploys do
  @moduledoc """
  Checks every minute for scheduled posts that became due since the last
  check and deploys their sites (`Feather.Publishing.deploy_due_posts/2`).
  The first check after boot has no lower bound, so it catches up on the
  posts that became due while the CMS was down.

  Started by `Feather.Application`; it does not start (`:ignore`) when
  disabled, as in tests:

      config :feather, Feather.Publishing.ScheduledDeploys, enabled: false

  Options, given to `start_link/1` or in that config (options win):
  `:enabled`, `:deploy` (a function of the window `from` and `to`, for
  tests), `:name`, `:interval` and `:initial_delay` in milliseconds (both a
  minute by default). A failing check is logged and not repeated: the next
  check starts where it ended.
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

    state = %{
      interval: interval,
      deploy: Keyword.get(opts, :deploy, &Feather.Publishing.deploy_due_posts/2),
      last_checked_at: nil
    }

    schedule(Keyword.get(opts, :initial_delay, interval))
    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    now = DateTime.utc_now()
    check(state.deploy, state.last_checked_at, now)
    schedule(state.interval)
    {:noreply, %{state | last_checked_at: now}}
  end

  defp schedule(delay), do: Process.send_after(self(), :check, delay)

  defp check(deploy, from, to) do
    case deploy.(from, to) do
      [_ | _] = targets ->
        domains = Enum.map_join(targets, ", ", & &1.site.domain)
        Logger.info("Scheduled posts became due, deploying #{domains}")

      _none ->
        :ok
    end
  catch
    kind, reason ->
      Logger.error(
        "Checking for due scheduled posts failed: " <>
          Exception.format(kind, reason, __STACKTRACE__)
      )
  end
end
