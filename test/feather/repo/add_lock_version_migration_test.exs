defmodule Feather.Repo.AddLockVersionMigrationTest do
  use Feather.MigrationCase, async: false

  @add_last_deployed_at 20_261_009_130_934
  @add_lock_version 20_261_009_133_713

  @now "2026-01-02T10:00:00.000000Z"

  setup %{migrate: migrate} do
    migrate.(:up, @add_last_deployed_at)

    Repo.query!("""
    INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
    VALUES ('site', 'site', 'Site', 'example.com', '#{@now}', '#{@now}')
    """)

    Repo.query!("""
    INSERT INTO posts (id, public_id, site_id, inserted_at, updated_at)
    VALUES ('post', 'post', 'site', '#{@now}', '#{@now}')
    """)

    Repo.query!("""
    INSERT INTO pages (id, public_id, site_id, slug, inserted_at, updated_at)
    VALUES ('page', 'page', 'site', '/page', '#{@now}', '#{@now}')
    """)

    Repo.query!("""
    INSERT INTO projects (id, public_id, site_id, title, slug, short_description, started_at,
                          inserted_at, updated_at)
    VALUES ('project', 'project', 'site', 'Project', '/project', 'Built it', '2026-01-01',
            '#{@now}', '#{@now}')
    """)

    :ok
  end

  test "starts the counter of existing posts, pages and projects at 1", %{migrate: migrate} do
    migrate.(:up, @add_lock_version)

    for table <- ~w(posts pages projects) do
      assert rows("SELECT lock_version FROM #{table}") == [[1]]
    end
  end

  test "rolls back", %{migrate: migrate} do
    migrate.(:up, @add_lock_version)
    migrate.(:down, @add_lock_version)

    for table <- ~w(posts pages projects) do
      columns = rows("SELECT name FROM pragma_table_info('#{table}')") |> List.flatten()
      refute "lock_version" in columns
    end
  end
end
