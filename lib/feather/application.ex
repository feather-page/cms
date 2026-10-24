defmodule Feather.Application do
  @moduledoc false

  use Application

  alias Feather.Publishing.Deploy
  alias Feather.StaticSite.ImageVariants

  require Logger

  @impl true
  def start(_type, _args) do
    :ok = Feather.Encryption.validate_key!()

    children = [
      FeatherWeb.Telemetry,
      Feather.Repo,
      {Phoenix.PubSub, name: Feather.PubSub},
      Feather.Media.CleanupScheduler,
      {Task.Supervisor, name: Feather.TaskSupervisor},
      {Registry, keys: :unique, name: Feather.Publishing.Registry},
      Feather.Publishing.ScheduledDeploys,
      Feather.Fediverse.Limiter,
      {Feather.Fediverse.Limiter, pool: :inbox},
      Feather.Fediverse.RateLimit,
      Feather.Fediverse.Scheduler,
      FeatherWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Feather.Supervisor]
    remove_stale_exports()

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      release_stale_deploy_locks()
      start_image_variant_backfill()
      {:ok, pid}
    end
  end

  # bin/server migrates before it starts the app, so the images' records are current.
  defp start_image_variant_backfill do
    if Application.get_env(:feather, :backfill_image_variants, true) do
      Task.Supervisor.start_child(Feather.TaskSupervisor, fn ->
        Logger.info("Bringing image variants in line with the sites' themes")
        ImageVariants.backfill()
        Logger.info("Image variants are in line")
      end)
    end
  end

  # No deploy survives a restart.
  defp release_stale_deploy_locks do
    Feather.Publishing.release_stale_locks()
  rescue
    exception ->
      Logger.warning("Could not release stale deploy locks: #{Exception.message(exception)}")
  end

  defp remove_stale_exports do
    Deploy.remove_stale_exports()
  rescue
    exception ->
      Logger.warning("Could not remove stale exports: #{Exception.message(exception)}")
  end

  @impl true
  def config_change(changed, _new, removed) do
    FeatherWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
