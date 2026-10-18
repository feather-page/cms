defmodule Feather.Application do
  @moduledoc false

  use Application

  alias Feather.Publishing.Deploy

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
      FeatherWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Feather.Supervisor]
    remove_stale_exports()

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      release_stale_deploy_locks()
      {:ok, pid}
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
