defmodule Feather.Repo.OneDeploymentTargetPerSiteMigrationTest do
  use Feather.MigrationCase, async: false

  @previous 20_261_017_170_258
  @one_target 20_261_018_103_502

  setup %{migrate: migrate} do
    migrate.(:up, @previous)

    for site <- ["first", "second"] do
      Repo.query!(
        """
        INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
        VALUES (?, ?, ?, ?, '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z')
        """,
        [site, site, site, "#{site}.example.com"]
      )

      Repo.query!(
        """
        INSERT INTO deployment_targets (id, public_id, site_id, provider, public_hostname,
                                        inserted_at, updated_at)
        VALUES (?, ?, ?, 'hetzner_ftps', ?, '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z')
        """,
        [site, site, site, "#{site}.example.com"]
      )
    end

    :ok
  end

  defp columns, do: List.flatten(rows("SELECT name FROM pragma_table_info('deployment_targets')"))

  defp insert_second_target do
    Repo.query("""
    INSERT INTO deployment_targets (id, public_id, site_id, provider, inserted_at, updated_at)
    VALUES ('again', 'again', 'first', 'ftps', '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z')
    """)
  end

  test "renames the provider, drops the hostname and allows one target per site", %{
    migrate: migrate
  } do
    migrate.(:up, @one_target)

    assert rows("SELECT id, provider FROM deployment_targets ORDER BY id") == [
             ["first", "ftps"],
             ["second", "ftps"]
           ]

    refute "public_hostname" in columns()
    assert {:error, %Exqlite.Error{message: message}} = insert_second_target()
    assert message =~ "UNIQUE constraint failed: deployment_targets.site_id"
  end

  test "rolls back with the site's domain as hostname", %{migrate: migrate} do
    migrate.(:up, @one_target)
    migrate.(:down, @one_target)

    assert rows("SELECT id, provider, public_hostname FROM deployment_targets ORDER BY id") == [
             ["first", "hetzner_ftps", "first.example.com"],
             ["second", "hetzner_ftps", "second.example.com"]
           ]

    Repo.query!("UPDATE deployment_targets SET provider = 'ftps'")
    assert {:ok, _result} = insert_second_target()
  end
end
