defmodule Feather.MigrationCase do
  @moduledoc """
  Runs migrations on a database of their own, so the sandbox of the other
  tests is not involved. Tests get `migrate.(direction, version)` and fill
  the database with raw SQL (`rows/1`) written before the migration under
  test.
  """
  use ExUnit.CaseTemplate

  alias Feather.Repo

  using do
    quote do
      import Feather.MigrationCase, only: [rows: 1]

      alias Feather.Repo
    end
  end

  # Compiled once per test run: Ecto.Migrator would compile the files on
  # every run, and compiling them again redefines the modules.
  setup_all do
    %{migrations: migrations()}
  end

  defp migrations do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        migrations = compile_migrations()
        :persistent_term.put(__MODULE__, migrations)
        migrations

      migrations ->
        migrations
    end
  end

  defp compile_migrations do
    Ecto.Migrator.migrations_path(Repo)
    |> Path.join("*.exs")
    |> Path.wildcard()
    |> Enum.map(fn file ->
      {version, "_" <> _} = file |> Path.basename() |> Integer.parse()
      [{module, _binary}] = Code.compile_file(file)
      {version, module}
    end)
  end

  setup %{migrations: migrations} do
    path =
      Path.join(System.tmp_dir!(), "feather_migration_#{System.unique_integer([:positive])}.db")

    {:ok, repo} =
      Repo.start_link(
        name: nil,
        database: path,
        pool: DBConnection.ConnectionPool,
        pool_size: 1
      )

    Repo.put_dynamic_repo(repo)

    on_exit(fn ->
      for file <- [path, path <> "-wal", path <> "-shm"], do: File.rm(file)
    end)

    migrate = fn direction, to ->
      Ecto.Migrator.run(Repo, migrations, direction, to: to, dynamic_repo: repo, log: false)
    end

    %{migrate: migrate}
  end

  @doc "The rows a query returns."
  def rows(sql), do: Repo.query!(sql).rows
end
