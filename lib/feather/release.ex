defmodule Feather.Release do
  @moduledoc """
  Tasks run in a release, where Mix is not available:

      bin/feather eval "Feather.Release.migrate()"
      bin/feather eval 'Feather.Release.create_user("me@example.com", true)'
      bin/feather eval 'Feather.Release.create_api_token("me@example.com", "laptop")'

  `bin/migrate` and `bin/server` (in `rel/overlays/bin`) wrap the first.
  """

  @app :feather

  @doc """
  Runs all pending migrations. The repo is started with a single
  connection, so the migration never competes with itself for SQLite's
  write lock.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true), pool_size: 1)
    end

    :ok
  end

  @doc """
  Rolls back the given repo to a version.
  """
  def rollback(repo, version) do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version), pool_size: 1)

    :ok
  end

  @doc """
  Creates a confirmed user (or finds the existing one) and sets the super
  admin flag.
  """
  def create_user(email, super_admin? \\ false) do
    with_app(fn ->
      with {:ok, user} <- Feather.Accounts.get_or_create_user_by_email(email),
           {:ok, user} <- Feather.Accounts.set_super_admin(user, super_admin?) do
        IO.puts("User #{user.email} ready#{if super_admin?, do: " (super admin)", else: ""}.")
        {:ok, user}
      end
    end)
  end

  @doc """
  Creates an API token for the user with the given email and prints it.
  The token is shown only this once.
  """
  def create_api_token(email, name \\ nil) do
    with_app(fn ->
      case Feather.Accounts.get_user_by_email(String.downcase(String.trim(email))) do
        nil ->
          IO.puts(:stderr, "No user with email #{email}.")
          {:error, :not_found}

        user ->
          {:ok, token, _api_token} = Feather.Accounts.create_api_token(user, name)
          IO.puts(token)
          {:ok, token}
      end
    end)
  end

  defp with_app(fun) do
    load_app()
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, result, _} = Ecto.Migrator.with_repo(Feather.Repo, fn _repo -> fun.() end)
    result
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_loaded(@app)
  end
end
