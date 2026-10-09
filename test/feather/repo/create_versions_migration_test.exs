defmodule Feather.Repo.CreateVersionsMigrationTest do
  use Feather.MigrationCase, async: false

  @before_versions 20_261_006_180_000
  @create_versions 20_261_009_121_753

  @saved_at "2026-01-02T10:00:00.000000Z"
  @content ~s([{"id":"b1","type":"paragraph","text":"Hello"}])

  setup %{migrate: migrate} do
    migrate.(:up, @before_versions)
    insert_records()
    :ok
  end

  test "gives every record version 1 and publishes it, except draft posts", %{migrate: migrate} do
    migrate.(:up, @create_versions)

    assert [
             [
               "published-post",
               1,
               "/published",
               "Published",
               "📝",
               "a,b",
               @content,
               nil,
               @saved_at,
               "2026-01-01T09:00:00.000000Z",
               "img-1",
               "img-2"
             ],
             [
               "draft-post",
               1,
               "/draft",
               "Draft",
               nil,
               nil,
               @content,
               nil,
               @saved_at,
               "2026-01-01T09:00:00.000000Z",
               nil,
               nil
             ]
           ] =
             rows("""
             SELECT post_id, number, slug, title, emoji, tags, content, published_by_id,
                    published_at, publish_at, header_image_id, thumbnail_image_id
             FROM post_versions ORDER BY title DESC
             """)

    assert rows("SELECT id, published_version_id IS NOT NULL FROM posts ORDER BY id") ==
             [["draft-post", 0], ["published-post", 1]]

    assert rows("SELECT published_version_id FROM posts WHERE id = 'published-post'") ==
             rows("SELECT id FROM post_versions WHERE post_id = 'published-post'")

    assert rows("""
           SELECT page_id, number, slug, title, content, page_type, header_image_id, published_at
           FROM page_versions
           """) == [["page", 1, "/about", "About", @content, "books", "img-1", @saved_at]]

    assert rows("SELECT published_version_id = v.id FROM pages JOIN page_versions v") == [[1]]

    assert rows("""
           SELECT project_id, number, slug, title, short_description, started_at, status,
                  project_type, links, published_at
           FROM project_versions
           """) == [
             [
               "project",
               1,
               "/cms",
               "CMS",
               "Builds sites",
               "2024-03-01",
               "completed",
               "open_source",
               ~s([{"label":"Code","url":"https://example.com"}]),
               @saved_at
             ]
           ]

    assert rows("SELECT published_version_id = v.id FROM projects JOIN project_versions v") ==
             [[1]]
  end

  test "deleting a record deletes its versions", %{migrate: migrate} do
    migrate.(:up, @create_versions)

    Repo.query!("DELETE FROM posts WHERE id = 'published-post'")

    assert rows("SELECT post_id FROM post_versions") == [["draft-post"]]
  end

  test "rolls back", %{migrate: migrate} do
    migrate.(:up, @create_versions)
    migrate.(:down, @create_versions)

    assert rows("SELECT name FROM sqlite_master WHERE name LIKE '%_versions'") == []
    assert rows("SELECT count(*) FROM posts") == [[2]]
    columns = rows("SELECT name FROM pragma_table_info('posts')") |> List.flatten()
    refute "published_version_id" in columns
  end

  defp insert_records do
    Repo.query!("""
    INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
    VALUES ('site', 'site', 'Site', 'example.com', '#{@saved_at}', '#{@saved_at}')
    """)

    Repo.query!("""
    INSERT INTO images (id, public_id, site_id, filename, content_type, byte_size,
                        inserted_at, updated_at)
    VALUES ('img-1', 'img1', 'site', 'a.jpg', 'image/jpeg', 1, '#{@saved_at}', '#{@saved_at}'),
           ('img-2', 'img2', 'site', 'b.jpg', 'image/jpeg', 1, '#{@saved_at}', '#{@saved_at}')
    """)

    Repo.query!("""
    INSERT INTO posts (id, public_id, site_id, title, slug, emoji, tags, content, draft,
                       publish_at, header_image_id, thumbnail_image_id, inserted_at, updated_at)
    VALUES ('published-post', 'p1', 'site', 'Published', '/published', '📝', 'a,b', '#{@content}',
            0, '2026-01-01T09:00:00.000000Z', 'img-1', 'img-2', '2025-12-01T00:00:00.000000Z',
            '#{@saved_at}'),
           ('draft-post', 'p2', 'site', 'Draft', '/draft', NULL, NULL, '#{@content}', 1,
            '2026-01-01T09:00:00.000000Z', NULL, NULL, '2025-12-01T00:00:00.000000Z',
            '#{@saved_at}')
    """)

    Repo.query!("""
    INSERT INTO pages (id, public_id, site_id, title, slug, content, page_type,
                       header_image_id, inserted_at, updated_at)
    VALUES ('page', 'pg1', 'site', 'About', '/about', '#{@content}', 'books', 'img-1',
            '2025-12-01T00:00:00.000000Z', '#{@saved_at}')
    """)

    Repo.query!("""
    INSERT INTO projects (id, public_id, site_id, title, slug, short_description, started_at,
                          status, project_type, links, inserted_at, updated_at)
    VALUES ('project', 'pr1', 'site', 'CMS', '/cms', 'Builds sites', '2024-03-01', 'completed',
            'open_source', '[{"label":"Code","url":"https://example.com"}]',
            '2025-12-01T00:00:00.000000Z', '#{@saved_at}')
    """)
  end
end
