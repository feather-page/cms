defmodule Feather.Publishing.Deploy do
  @moduledoc """
  The deploy pipeline of one deployment target, run synchronously (the
  public entry points in `Feather.Publishing` run it under
  `Feather.TaskSupervisor`):

    1. take the target's deploy lock (see "Concurrent deploys")
    2. export the site into a fresh directory next to the live one
       (`Feather.StaticSite.Export` into a `FileSink`), with the content
       the target shows (`DeploymentTarget.exported_content/1`)
    3. precompress it (`Feather.StaticSite.Precompress`)
    4. swap it in as the live directory `<storage_root>/static_site/<target id>/public`
    5. sync the live directory with rclone (`Feather.Publishing.Rclone`)
    6. record the time the export started as the target's `last_deployed_at`
       (`Feather.Publishing.record_deploy/2`): what was published later is
       not in this deploy
    7. release the lock (always) and broadcast a notice

  A failure before step 4 leaves the live directory untouched.

  ## Concurrent deploys

  When the lock is held by a running deploy, the request waits for it,
  retrying every 5 seconds up to 60 times like Rails did. Waiting requests
  are coalesced: at most one request per target waits, others return
  `{:ok, :coalesced}` at once. The waiting request exports after the
  running deploy has finished, so it includes every change made up to
  then. (Coalescing uses `Feather.Publishing.Registry`, so it works within
  one node, which is all a SQLite app has.)
  """

  require Logger

  alias Feather.Media
  alias Feather.Publishing
  alias Feather.Publishing.{DeploymentTarget, Rclone}
  alias Feather.Repo
  alias Feather.StaticSite.{Export, FileSink, Precompress, Routes}

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
    * `:staging_sites_path` - passed to `Feather.Publishing.Rclone.deploy/3`
  """
  @spec run(DeploymentTarget.t(), keyword()) ::
          {:ok, :deployed | :coalesced} | {:error, String.t()}
  def run(%DeploymentTarget{} = target, opts \\ []) do
    target = Repo.preload(target, :site, force: true)

    result =
      with_lock(target, opts, fn ->
        try do
          build_and_sync(target, opts)
        rescue
          exception -> {:error, Exception.message(exception)}
        end
      end)

    notify(target, result)
    result
  end

  @doc "The directory holding a target's builds."
  @spec build_path(DeploymentTarget.t()) :: Path.t()
  def build_path(%DeploymentTarget{id: id}),
    do: Path.join([Media.storage_root(), "static_site", id])

  @doc "The live directory of a target: the last successful export."
  @spec live_dir(DeploymentTarget.t()) :: Path.t()
  def live_dir(%DeploymentTarget{} = target), do: Path.join(build_path(target), "public")

  ## Lock

  defp with_lock(target, opts, fun) do
    if Publishing.acquire_deploy_lock(target) do
      locked(target, fun)
    else
      wait_for_lock(target, opts, fun)
    end
  end

  defp locked(target, fun) do
    fun.()
  after
    Publishing.release_deploy_lock(target)
  end

  defp wait_for_lock(target, opts, fun) do
    key = {:waiting, target.id}

    case Registry.register(@registry, key, nil) do
      {:ok, _owner} ->
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
    {:error, "another deploy is still running"}
  end

  defp retry_lock(target, retries, interval, fun) do
    Process.sleep(interval)

    if Publishing.acquire_deploy_lock(target),
      do: fun.(),
      else: retry_lock(target, retries - 1, interval, fun)
  end

  ## Pipeline

  defp build_and_sync(target, opts) do
    started_at = DateTime.utc_now()
    sink = FileSink.new(build_path(target))

    try do
      Export.run(target.site, Routes.for(target, :deployed), sink,
        content: DeploymentTarget.exported_content(target)
      )

      Precompress.run(FileSink.dir(sink), Keyword.take(opts, [:brotli]))
      replace_live_dir(FileSink.dir(sink), live_dir(target))
    after
      FileSink.discard(sink)
    end

    with {:ok, _output} <-
           Rclone.deploy(
             target,
             live_dir(target) <> "/",
             Keyword.take(opts, [:runner, :staging_sites_path])
           ) do
      Publishing.record_deploy(target, started_at)
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

  defp notify(target, {:ok, :deployed}) do
    Publishing.broadcast_notice(target.site, "Site built.", "https://#{target.public_hostname}")
  end

  defp notify(_target, {:ok, :coalesced}), do: :ok

  defp notify(target, {:error, message}) do
    Logger.error("Deploying target #{target.id} (#{target.public_hostname}) failed: #{message}")

    Publishing.broadcast_notice(
      target.site,
      "Deploying to #{target.public_hostname} failed: #{Feather.Content.Blocks.truncate(message, 300)}"
    )
  end
end
