defmodule Feather.Repo.BackfillRedirectsMigrationTest do
  use Feather.MigrationCase, async: false

  @create_redirects 20_261_020_173_830
  @backfill_redirects 20_261_020_180_302

  @before "2026-01-01T10:00:00.000000Z"

  setup %{migrate: migrate} do
    migrate.(:up, @create_redirects)

    for site <- ["site", "other"] do
      Repo.query!(
        """
        INSERT INTO sites (id, public_id, title, domain, inserted_at, updated_at)
        VALUES (?1, ?1, ?1, ?1, ?2, ?2)
        """,
        [site, @before]
      )
    end

    :ok
  end

  test "turns a version history of three slugs into two redirects to the record", %{
    migrate: migrate
  } do
    insert_record(:post, "post", ["/ssh-copy-id", "/install-ssh-key", "/ssh-key"])

    migrate.(:up, @backfill_redirects)

    assert rows("""
           SELECT site_id, old_path, kind, post_id, page_id, project_id, target_path
           FROM redirects ORDER BY old_path
           """) == [
             ["site", "/install-ssh-key", "permanent", "post", nil, nil, nil],
             ["site", "/ssh-copy-id", "permanent", "post", nil, nil, nil]
           ]

    assert [[12, 12]] =
             rows("SELECT min(length(public_id)), max(length(public_id)) FROM redirects")

    assert [[changed], [unchanged]] =
             rows("SELECT updated_at FROM sites WHERE id IN ('site', 'other') ORDER BY id DESC")

    assert changed > @before
    assert unchanged == @before
  end

  test "skips an old URL another record holds, as it is or as published", %{migrate: migrate} do
    insert_record(:post, "post", ["/ssh-copy-id", "/install-ssh-key", "/old-key", "/ssh-key"])
    insert_record(:page, "draft", ["/never-published"], current_slug: "/ssh-copy-id", draft: true)
    insert_record(:page, "moved", ["/old-key"], current_slug: "/moved-on")

    migrate.(:up, @backfill_redirects)

    assert rows("SELECT old_path, post_id FROM redirects ORDER BY old_path") == [
             ["/install-ssh-key", "post"]
           ]
  end

  test "redirects old project URLs under /projects/ and the public id URL of a post that got a slug",
       %{migrate: migrate} do
    insert_record(:project, "project", ["/cms", "/feather"])
    insert_record(:post, "untitled", [nil, "/named"], public_id: "AbC123")

    migrate.(:up, @backfill_redirects)

    assert rows("SELECT old_path, post_id, project_id FROM redirects ORDER BY old_path") == [
             ["/posts/abc123", "untitled", nil],
             ["/projects/cms", nil, "project"]
           ]
  end

  test "keeps an existing redirect and gives a path two records left to the later one", %{
    migrate: migrate
  } do
    insert_record(:post, "first", ["/shared", "/first"], published_at: "2026-01-01")
    insert_record(:post, "second", ["/shared", "/second"], published_at: "2026-02-01")
    insert_record(:post, "third", ["/kept", "/third"])

    Repo.query!("""
    INSERT INTO redirects (id, public_id, site_id, old_path, kind, target_path,
                           inserted_at, updated_at)
    VALUES ('manual', 'manual', 'site', '/kept', 'temporary', '/', '#{@before}', '#{@before}')
    """)

    migrate.(:up, @backfill_redirects)

    assert rows("SELECT old_path, post_id, target_path FROM redirects ORDER BY old_path") == [
             ["/kept", nil, "/"],
             ["/shared", "second", nil]
           ]
  end

  defp insert_record(type, id, version_slugs, opts \\ []) do
    {table, versions, owner} = tables(type)
    {columns, values} = type |> required_columns() |> Enum.unzip()
    columns = Enum.join(columns, ", ")
    values = Enum.join(values, ", ")
    published_at = Keyword.get(opts, :published_at, "2026-01-01")

    Repo.query!(
      """
      INSERT INTO #{table} (id, public_id, site_id, title, slug, inserted_at, updated_at, #{columns})
      VALUES (?1, ?2, 'site', ?1, ?3, ?4, ?4, #{values})
      """,
      [
        id,
        Keyword.get(opts, :public_id, id),
        Keyword.get(opts, :current_slug, List.last(version_slugs)),
        @before
      ]
    )

    for {slug, number} <- Enum.with_index(version_slugs, 1) do
      Repo.query!(
        """
        INSERT INTO #{versions} (id, #{owner}, number, published_at, title, slug, #{columns})
        VALUES (?1, ?2, ?3, ?4, ?2, ?5, #{values})
        """,
        ["#{id}-#{number}", id, number, "#{published_at}T0#{number}:00:00.000000Z", slug]
      )
    end

    unless opts[:draft] do
      Repo.query!("UPDATE #{table} SET published_version_id = ?1 WHERE id = ?2", [
        "#{id}-#{length(version_slugs)}",
        id
      ])
    end
  end

  defp tables(:post), do: {"posts", "post_versions", "post_id"}
  defp tables(:page), do: {"pages", "page_versions", "page_id"}
  defp tables(:project), do: {"projects", "project_versions", "project_id"}

  defp required_columns(:post), do: [{"publish_at", "'#{@before}'"}]
  defp required_columns(:page), do: [{"page_type", "'default'"}]

  defp required_columns(:project) do
    [
      {"short_description", "'Builds sites'"},
      {"started_at", "'2024-03-01'"},
      {"status", "'ongoing'"},
      {"project_type", "'personal'"}
    ]
  end
end
