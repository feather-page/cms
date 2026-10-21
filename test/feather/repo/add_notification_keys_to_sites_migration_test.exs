defmodule Feather.Repo.AddNotificationKeysToSitesMigrationTest do
  use Feather.MigrationCase, async: false

  @add_alt_to_images 20_261_021_150_316
  @add_notification_keys 20_261_021_151_928

  setup %{migrate: migrate} do
    migrate.(:up, @add_alt_to_images)

    for id <- ["one", "two"] do
      Repo.query!("""
      INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
      VALUES ('#{id}', '#{id}', 'Site', '#{id}.example.com',
              '2026-01-01T10:00:00.000000Z', '2026-01-01T10:00:00.000000Z')
      """)
    end

    :ok
  end

  test "gives every existing site its own IndexNow key and no archive.org keys", %{
    migrate: migrate
  } do
    migrate.(:up, @add_notification_keys)

    [[one, nil], [two, nil]] =
      rows("SELECT indexnow_key, archive_org_keys FROM sites ORDER BY id")

    assert one =~ ~r/\A[0-9a-f]{32}\z/
    assert two =~ ~r/\A[0-9a-f]{32}\z/
    assert one != two
  end

  test "rolls back", %{migrate: migrate} do
    migrate.(:up, @add_notification_keys)
    migrate.(:down, @add_notification_keys)

    columns = List.flatten(rows("SELECT name FROM pragma_table_info('sites')"))
    refute "indexnow_key" in columns
    refute "archive_org_keys" in columns
  end
end
