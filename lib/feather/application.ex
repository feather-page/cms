defmodule Feather.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Fail fast on a malformed CONFIG_ENCRYPTION_KEY.
    :ok = Feather.Encryption.validate_key!()

    children = [
      FeatherWeb.Telemetry,
      Feather.Repo,
      {Phoenix.PubSub, name: Feather.PubSub},
      # Deletes orphaned images daily (ignored when disabled, as in tests)
      Feather.Media.CleanupScheduler,
      # Deploys run as tasks; the registry coalesces waiting deploys.
      {Task.Supervisor, name: Feather.TaskSupervisor},
      {Registry, keys: :unique, name: Feather.Publishing.Registry},
      # Start to serve requests, typically the last entry
      FeatherWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Feather.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      release_stale_deploy_locks()
      {:ok, pid}
    end
  end

  # No deploy survives a restart, so deploy locks still held are stale.
  defp release_stale_deploy_locks do
    Feather.Publishing.release_stale_locks()
  rescue
    exception ->
      Logger.warning("Could not release stale deploy locks: #{Exception.message(exception)}")
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FeatherWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
