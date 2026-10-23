defmodule Feather.Repo.DropApiTokensMigrationTest do
  use Feather.MigrationCase, async: false

  @previous 20_261_021_154_210
  @drop_api_tokens 20_261_023_151_501

  setup %{migrate: migrate} do
    migrate.(:up, @previous)

    Repo.query!("""
    INSERT INTO users (id, email, inserted_at, updated_at)
    VALUES ('user', 'me@example.com', '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z')
    """)

    Repo.query!("""
    INSERT INTO api_tokens (id, user_id, token_digest, token_prefix, inserted_at, updated_at)
    VALUES ('token', 'user', 'digest', 'prefix', '2026-01-01T10:00:00Z', '2026-01-01T10:00:00Z')
    """)

    :ok
  end

  test "drops the API tokens with their table and keeps the users", %{migrate: migrate} do
    migrate.(:up, @drop_api_tokens)

    assert rows("SELECT name FROM sqlite_master WHERE name LIKE 'api_tokens%'") == []
    assert rows("SELECT id FROM users") == [["user"]]
  end

  test "rolls back to an empty table", %{migrate: migrate} do
    migrate.(:up, @drop_api_tokens)
    migrate.(:down, @drop_api_tokens)

    assert rows("SELECT count(*) FROM api_tokens") == [[0]]
  end
end
