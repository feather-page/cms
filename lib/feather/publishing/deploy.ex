defmodule Feather.Publishing.Deploy do
  @moduledoc """
  The deploy pipeline of one deployment target, run synchronously (the
  public entry points in `Feather.Publishing` run it under
  `Feather.TaskSupervisor`):

    1. take the target's deploy lock (see "Concurrent deploys")
    2. export the site's published versions into a fresh directory next
       to the live one (`Feather.StaticSite.Export` into a `FileSink`)
    3. precompress it (`Feather.StaticSite.Precompress`)
    4. swap it in as the live directory `<storage_root>/static_site/<target id>/public`
    5. sync the live directory with rclone (`Feather.Publishing.Rclone`)
    6. record the time the export started as the target's `last_deployed_at`
       (`Feather.Publishing.record_deploy/2`): what was published later is
       not in this deploy
    7. release the lock (always) and broadcast a notice

  A failure before step 4 leaves the live directory untouched.

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
          exception -> {:error, Exception.message(exception)}
        end
      end)

    {result, step} =
      case result do
        {:error, :lock_timeout} -> {{:error, "another deploy is still running"}, :waiting}
        result -> {result, own_step(target)}
      end

    Publishing.clear_deploy_progress(target)
    notify(target, result, started_at, step)
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

  @doc "The directory holding a target's builds."
  @spec build_path(DeploymentTarget.t()) :: Path.t()
  def build_path(%DeploymentTarget{id: id}),
    do: Path.join([Media.storage_root(), "static_site", id])

  @doc "The live directory of a target: the last successful export."
  @spec live_dir(DeploymentTarget.t()) :: Path.t()
  def live_dir(%DeploymentTarget{} = target), do: Path.join(build_path(target), "public")

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
    export_started_at = DateTime.utc_now()
    sink = FileSink.new(build_path(target))

    try do
      Publishing.put_deploy_progress(target, :build, started_at)

      Export.run(target.site, Routes.for(target), sink)

      Publishing.put_deploy_progress(target, :compress, started_at)
      Precompress.run(FileSink.dir(sink), Keyword.take(opts, [:brotli]))
      replace_live_dir(FileSink.dir(sink), live_dir(target))
    after
      FileSink.discard(sink)
    end

    Publishing.put_deploy_progress(target, :upload, started_at)

    with {:ok, _output} <-
           Rclone.deploy(
             target,
             live_dir(target) <> "/",
             Keyword.take(opts, [:runner])
           ) do
      Publishing.record_deploy(target, export_started_at)
      {:ok, :deployed}
    end
  end

  # Two renames: the live directory is missing only between them, and an
  # export that failed earlier never gets here.
  defp replace_live_dir(new_dir, live_dir) do
    old_dir = "#{live_dir}.old-#{Feather.PublicId.generate()}"

    case File.rename(live_dir, old_dir) do
      :ok ->
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        raise File.RenameError,
          source: live_dir,
          destination: old_dir,
          reason: reason,
          action: "move aside the live directory"
    end

    File.rename!(new_dir, live_dir)
    File.rm_rf!(old_dir)
  end

  ## Notices

  defp notify(target, {:ok, :deployed}, started_at, _step) do
    Publishing.broadcast_notice(target.site, %{
      kind: :success,
      title: "#{target.site.title} is live",
      message: "#{target.public_hostname} · deployed #{duration(started_at)}",
      url: "https://#{target.public_hostname}",
      link_label: "Open site",
      external: true
    })
  end

  defp notify(_target, {:ok, :coalesced}, _started_at, _step), do: :ok

  defp notify(target, {:error, message}, _started_at, step) do
    Logger.error("Deploying target #{target.id} (#{target.public_hostname}) failed: #{message}")

    Publishing.broadcast_notice(target.site, %{
      kind: :error,
      title: "Deploy to #{target.public_hostname} failed",
      message: failure_message(step, Blocks.truncate(message, 300)),
      retry: target.public_id
    })
  end

  # Until the live directory is swapped in (before :upload), the site
  # online is untouched; a failed upload may have changed part of it.
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
