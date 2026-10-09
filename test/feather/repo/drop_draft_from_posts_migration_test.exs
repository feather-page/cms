defmodule Feather.Repo.DropDraftFromPostsMigrationTest do
  use Feather.MigrationCase, async: false

  @create_versions 20_261_009_121_753
  @drop_draft 20_261_009_123_922

  @saved_at "2026-01-02T10:00:00.000000Z"

  setup %{migrate: migrate} do
    migrate.(:up, @create_versions)

    Repo.query!("""
    INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
    VALUES ('site', 'site', 'Site', 'example.com', '#{@saved_at}', '#{@saved_at}')
    """)

    Repo.query!("""
    INSERT INTO posts (id, public_id, site_id, title, content, draft, publish_at,
                       inserted_at, updated_at)
    VALUES ('published-post', 'p1', 'site', 'Published', '[]', 0, '#{@saved_at}',
            '#{@saved_at}', '#{@saved_at}'),
           ('draft-post', 'p2', 'site', 'Draft', '[]', 1, '#{@saved_at}',
            '#{@saved_at}', '#{@saved_at}')
    """)

    Repo.query!("""
    INSERT INTO post_versions (id, post_id, number, title, content, publish_at, published_at)
    VALUES ('v1', 'published-post', 1, 'Published', '[]', '#{@saved_at}', '#{@saved_at}')
    """)

    Repo.query!("UPDATE posts SET published_version_id = 'v1' WHERE id = 'published-post'")
    :ok
  end

  test "drops the draft column and keeps the posts", %{migrate: migrate} do
    migrate.(:up, @drop_draft)

    refute "draft" in post_columns()

    assert rows("SELECT id, published_version_id FROM posts ORDER BY id") ==
             [["draft-post", nil], ["published-post", "v1"]]
  end

  test "rolls back: posts without a published version are drafts", %{migrate: migrate} do
    migrate.(:up, @drop_draft)
    migrate.(:down, @drop_draft)

    assert rows("SELECT id, draft FROM posts ORDER BY id") ==
             [["draft-post", 1], ["published-post", 0]]
  end

  defp post_columns, do: rows("SELECT name FROM pragma_table_info('posts')") |> List.flatten()
end
