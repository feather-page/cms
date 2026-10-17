defmodule Feather.Repo.RemoveStagingAndBackupTargetsMigrationTest do
  use Feather.MigrationCase, async: false

  @previous 20_261_016_165_602
  @remove_targets 20_261_017_170_258

  setup %{migrate: migrate} do
    migrate.(:up, @previous)

    Repo.query!("""
    INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
    VALUES ('site', 'site', 'Site', 'example.com', '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z')
    """)

    for {id, type, provider} <- [
          {"production", "production", "hetzner_ftps"},
          {"staging", "staging", "internal"},
          {"backup", "backup", "hetzner_ftps"},
          {"internal", "production", "internal"},
          {"fastmail", "production", "fastmail"}
        ] do
      Repo.query!(
        """
        INSERT INTO deployment_targets (id, public_id, site_id, type, provider, public_hostname,
                                        inserted_at, updated_at)
        VALUES (?, ?, 'site', ?, ?, ?, '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z')
        """,
        [id, id, type, provider, "#{id}.example.com"]
      )
    end

    :ok
  end

  defp columns, do: List.flatten(rows("SELECT name FROM pragma_table_info('deployment_targets')"))

  test "keeps only the external production targets and drops the type", %{migrate: migrate} do
    migrate.(:up, @remove_targets)

    assert rows("SELECT id, provider FROM deployment_targets") == [
             ["production", "hetzner_ftps"]
           ]

    refute "type" in columns()
  end

  test "rolls back", %{migrate: migrate} do
    migrate.(:up, @remove_targets)
    migrate.(:down, @remove_targets)

    assert "type" in columns()
    assert rows("SELECT type FROM deployment_targets") == [["production"]]
  end
end
