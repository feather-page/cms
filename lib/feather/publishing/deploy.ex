defmodule Feather.Publishing.Deploy do
  @moduledoc """
  The deploy pipeline of a site's deployment target, run synchronously (the
  public entry points in `Feather.Publishing` run it under
  `Feather.TaskSupervisor`):

    1. take the target's deploy lock (see "Concurrent deploys")
    2. export the site's published versions, canonically at
       `https://<site domain>/`, into a fresh directory in
       `<storage_root>/static_site/` (`Feather.StaticSite.Export` into a
       `FileSink`)
    3. precompress it (`Feather.StaticSite.Precompress`)
    4. sync it with rclone (`Feather.Publishing.Rclone`)
    5. record the time the export started as the target's `last_deployed_at`
       (`Feather.Publishing.record_deploy/2`): what was published or
       changed later is not in this deploy. The time is taken once running
       write transactions have committed, so what they stamped earlier is
       in the export
    6. remove the directory and release the lock (both always), broadcast
       a notice

  A failure before step 4 leaves the site online untouched. No export
  persists between deploys; `remove_stale_exports/0` clears what a deploy
  interrupted by a restart left behind.

  Each step is reported with `Feather.Publishing.put_deploy_progress/3`
  (`:waiting`, `:build`, `:compress`, `:upload`), so the deployments page
  can show where a deploy is. The notice at the end says how long the
  deploy took, or at which step it failed and with which message.

  ## Concurrent deploys

  When the lock is held by a running deploy, the request waits for it,
  retrying every 5 seconds up to 60 times. Waiting requests are
  coalesced: at most one request per target waits, others return
  `{:ok, :coalesced}` at once. The waiting request exports after the
  running deploy has finished, so it includes every change made up to
  then. (Coalescing uses `Feather.Publishing.Registry`, so it works within
  one node, which is all a SQLite app has.)
  """

  alias Feather.Content.Blocks
  alias Feather.Media
  alias Feather.Publishing
  alias Feather.Publishing.{DeploymentTarget, Rclone}
  alias Feather.Repo
  alias Feather.StaticSite.{Export, FileSink, Precompress, Routes}

  require Logger

  @registry Feather.Publishing.Registry
  @lock_retries 60
  @lock_retry_interval 5_000

  @doc """
  Deploys the target. Returns `{:ok, :deployed}`, `{:ok, :coalesced}` when
  another waiting request will do the work, or `{:error, message}`.

  ## Options

    * `:runner` - the rclone command runner (see `Feather.Publishing.Rclone`)
    * `:lock_retries`, `:lock_retry_interval` - waiting for the lock
      (default 60 times every 5000 ms)
    * `:brotli` - passed to `Feather.StaticSite.Precompress.run/2`
  """
  @spec run(DeploymentTarget.t(), keyword()) ::
          {:ok, :deployed | :coalesced} | {:error, String.t()}
  def run(%DeploymentTarget{} = target, opts \\ []) do
    target = Repo.preload(target, :site, force: true)
    started_at = DateTime.utc_now()

    result =
      with_lock(target, started_at, opts, fn ->
        try do
          build_and_sync(target, started_at, opts)
        rescue
          exception -> {{:error, Exception.message(exception)}, target.site}
        end
      end)

    {result, site, step} =
      case result do
        {:error, :lock_timeout} ->
          {{:error, "another deploy is still running"}, target.site, :waiting}

        {:ok, :coalesced} ->
          {{:ok, :coalesced}, target.site, nil}

        {result, site} ->
          {result, site, own_step(target)}
      end

    Publishing.clear_deploy_progress(target)
    notify(site, result, started_at, step)
    result
  end

  # The step this process recorded; the record may belong to another deploy
  # of the target.
  defp own_step(target) do
    case Registry.lookup(@registry, {:progress, target.id}) do
      [{pid, %{step: step}}] when pid == self() -> step
      _other -> nil
    end
  end

  @doc """
  Removes everything in `<storage_root>/static_site/`. Meant to run on
  boot: no deploy survives a restart, so any export there is stale.
  """
  @spec remove_stale_exports() :: :ok
  def remove_stale_exports do
    File.rm_rf!(exports_dir())
    :ok
  end

  defp exports_dir, do: Path.join(Media.storage_root(), "static_site")

  ## Lock

  defp with_lock(target, started_at, opts, fun) do
    if Publishing.acquire_deploy_lock(target) do
      locked(target, fun)
    else
      wait_for_lock(target, started_at, opts, fun)
    end
  end

  defp locked(target, fun) do
    fun.()
  after
    Publishing.release_deploy_lock(target)
  end

  defp wait_for_lock(target, started_at, opts, fun) do
    key = {:waiting, target.id}

    case Registry.register(@registry, key, nil) do
      {:ok, _owner} ->
        Publishing.put_deploy_progress(target, :waiting, started_at)
        retries = Keyword.get(opts, :lock_retries, @lock_retries)
        interval = Keyword.get(opts, :lock_retry_interval, @lock_retry_interval)

        try do
          retry_lock(target, retries, interval, fn ->
            # From now on a new request has to wait for this deploy.
            Registry.unregister(@registry, key)
            locked(target, fun)
          end)
        after
          Registry.unregister(@registry, key)
        end

      {:error, {:already_registered, _owner}} ->
        {:ok, :coalesced}
    end
  end

  defp retry_lock(target, 0, _interval, _fun) do
    Logger.warning("Deploy lock of target #{target.id} stuck, giving up")
    {:error, :lock_timeout}
  end

  defp retry_lock(target, retries, interval, fun) do
    Process.sleep(interval)

    if Publishing.acquire_deploy_lock(target),
      do: fun.(),
      else: retry_lock(target, retries - 1, interval, fun)
  end

  ## Pipeline

  defp build_and_sync(target, started_at, opts) do
    # An immediate transaction waits for running writes: what they stamped is in the export.
    {:ok, export_started_at} = Repo.transact(fn -> {:ok, DateTime.utc_now()} end)
    # The request may have waited for the lock: settings changed meanwhile belong in this deploy.
    target = Repo.preload(target, :site, force: true)
    {export_and_sync(target, export_started_at, started_at, opts), target.site}
  end

  defp export_and_sync(target, export_started_at, started_at, opts) do
    sink = FileSink.new(exports_dir())

    try do
      Publishing.put_deploy_progress(target, :build, started_at)

      routes = Routes.new(target.site, canonical_url: "https://#{target.site.domain}/")
      Export.run(target.site, routes, sink, now: export_started_at)

      Publishing.put_deploy_progress(target, :compress, started_at)
      Precompress.run(FileSink.dir(sink), Keyword.take(opts, [:brotli]))

      Publishing.put_deploy_progress(target, :upload, started_at)

      with {:ok, _output} <-
             Rclone.deploy(target, FileSink.dir(sink) <> "/", Keyword.take(opts, [:runner])) do
        Publishing.record_deploy(target, export_started_at)
        {:ok, :deployed}
      end
    rescue
      exception -> {:error, Exception.message(exception)}
    after
      FileSink.discard(sink)
    end
  end

  ## Notices

  defp notify(site, {:ok, :deployed}, started_at, _step) do
    Publishing.broadcast_notice(site, %{
      kind: :success,
      title: "#{site.title} is live",
      message: "#{site.domain} · deployed #{duration(started_at)}",
      url: "https://#{site.domain}",
      link_label: "Open site",
      external: true
    })
  end

  defp notify(_site, {:ok, :coalesced}, _started_at, _step), do: :ok

  defp notify(site, {:error, message}, _started_at, step) do
    Logger.error("Deploying #{site.domain} failed: #{message}")

    Publishing.broadcast_notice(site, %{
      kind: :error,
      title: "Deploy to #{site.domain} failed",
      message: failure_message(step, Blocks.truncate(message, 300)),
      retry: true
    })
  end

  # A failed upload may have changed part of the site online.
  defp failure_message(nil, message), do: "#{message}. The site online is unchanged."

  defp failure_message(:upload, message), do: "#{step_label(:upload)}: #{message}."

  defp failure_message(step, message),
    do: "#{step_label(step)}: #{message}. The site online is unchanged."

  defp step_label(step), do: Publishing.deploy_step_label(step, :running)

  defp duration(started_at) do
    case max(DateTime.diff(DateTime.utc_now(), started_at), 0) do
      0 ->
        "in under a second"

      1 ->
        "in 1 second"

      seconds when seconds < 60 ->
        "in #{seconds} seconds"

      seconds ->
        "in #{div(seconds, 60)}:#{seconds |> rem(60) |> to_string() |> String.pad_leading(2, "0")} min"
    end
  end
end
