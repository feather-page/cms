defmodule Feather.Release do
  @moduledoc """
  Tasks run in a release, where Mix is not available:

      bin/feather eval "Feather.Release.migrate()"
      bin/feather eval 'Feather.Release.create_user("me@example.com", true)'
      bin/feather eval "Feather.Release.backfill_suggestions()"

  `bin/migrate` and `bin/server` (in `rel/overlays/bin`) wrap the first.
  """

  alias Feather.Accounts.Scope
  alias Feather.Publishing
  alias Feather.Publishing.DeploymentTarget
  alias Feather.Sites.Site

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
    with_app(fn -> ensure_user(email, super_admin?) end)
  end

  defp ensure_user(email, super_admin?) do
    with {:ok, user} <- Feather.Accounts.get_or_create_user_by_email(email),
         {:ok, user} <- Feather.Accounts.set_super_admin(user, super_admin?) do
      IO.puts("User #{user.email} ready#{if super_admin?, do: " (super admin)", else: ""}.")
      {:ok, user}
    end
  end

  @doc """
  Replaces the provider config (credentials) of the deployment target of
  the site with the given domain. The admin does not edit credentials. The
  `ftps` provider takes `host`, `user`, `password` and `path`.

      bin/feather eval 'Feather.Release.set_target_config("www.example.org", %{"host" => "...", "user" => "...", "password" => "...", "path" => "..."})'
  """
  def set_target_config(domain, %{} = config) do
    domain = Site.normalize_domain(domain)

    with_app(fn ->
      import Ecto.Query, only: [from: 2]

      # Without the old config: it is replaced, and it may not decrypt.
      fields = DeploymentTarget.__schema__(:fields) -- [:config]

      query =
        from t in DeploymentTarget,
          join: s in assoc(t, :site),
          where: s.domain == ^domain,
          select: {struct(t, ^fields), s}

      case Feather.Repo.one(query) do
        nil ->
          IO.puts(:stderr, "No deployment target for #{domain}.")
          {:error, :not_found}

        {target, site} ->
          update_target_config(%{target | site: site}, config)
      end
    end)
  end

  defp update_target_config(target, config) do
    scope = Scope.for_site(target.site)

    with {:ok, updated} <- Publishing.update_target_config(scope, target, config) do
      IO.puts("Config of #{target.site.domain} (#{updated.provider}) set.")
      {:ok, updated}
    end
  end

  @doc """
  Fills in the model's suggestions (ADR 0026) for content from before they
  existed, site by site: the alt texts of all images
  (`Feather.Media.backfill_alt_texts/1`), and descriptions and short
  posts' meta titles and slugs of published records without unpublished
  changes, by publishing them again (`Feather.Content.backfill_suggestions/1`).
  Needs `OLLAMA_URL`. Deploy the sites by hand afterwards.
  """
  def backfill_suggestions do
    with_app(fn ->
      {:ok, _} = Application.ensure_all_started(:req)

      if Feather.Ollama.configured?() do
        Enum.each(Feather.Repo.all(Site), &backfill_site/1)
      else
        IO.puts(:stderr, "OLLAMA_URL is not set.")
        {:error, :not_configured}
      end
    end)
  end

  defp backfill_site(site) do
    scope = Scope.for_site(site)
    alt_texts = Feather.Media.backfill_alt_texts(scope)
    republished = scope |> Feather.Content.backfill_suggestions() |> length()

    IO.puts(
      "#{site.domain}: alt texts filled in: #{alt_texts}, records published again: #{republished}"
    )
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
