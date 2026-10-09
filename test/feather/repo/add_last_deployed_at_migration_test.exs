defmodule Feather.Repo.AddLastDeployedAtMigrationTest do
  use Feather.MigrationCase, async: false

  @drop_draft 20_261_009_123_922
  @add_last_deployed_at 20_261_009_130_934

  @updated_at "2026-01-02T10:00:00.000000Z"

  setup %{migrate: migrate} do
    migrate.(:up, @drop_draft)

    Repo.query!("""
    INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
    VALUES ('site', 'site', 'Site', 'example.com', '#{@updated_at}', '#{@updated_at}')
    """)

    Repo.query!("""
    INSERT INTO deployment_targets (id, public_id, site_id, type, provider, public_hostname,
                                    inserted_at, updated_at)
    VALUES ('target', 'target', 'site', 'production', 'internal', 'www.example.com',
            '2026-01-01T10:00:00.000000Z', '#{@updated_at}')
    """)

    :ok
  end

  test "takes the last deploy of existing targets from their updated_at", %{migrate: migrate} do
    migrate.(:up, @add_last_deployed_at)

    assert rows("SELECT last_deployed_at FROM deployment_targets") == [[@updated_at]]
  end

  test "rolls back", %{migrate: migrate} do
    migrate.(:up, @add_last_deployed_at)
    migrate.(:down, @add_last_deployed_at)

    refute "last_deployed_at" in (rows("SELECT name FROM pragma_table_info('deployment_targets')")
                                  |> List.flatten())
  end
end
