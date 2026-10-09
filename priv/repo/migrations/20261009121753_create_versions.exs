defmodule Feather.Repo.Migrations.CreateVersions do
  use Ecto.Migration

  # A version is a full copy of the record's content columns (ADR-0011).
  # Images stay rows of their own: a version copies the header and thumbnail
  # image ids, and its content refers to embedded images by public id.
  @copied_columns %{
    posts: ~w(title slug emoji tags content publish_at header_image_id thumbnail_image_id),
    pages: ~w(title slug emoji tags content page_type header_image_id thumbnail_image_id),
    projects: ~w(title slug emoji tags content short_description company role period started_at
      ended_at status project_type links header_image_id thumbnail_image_id)
  }

  def up do
    create_versions(:post_versions, :post_id, :posts, fn ->
      add :title, :string
      add :slug, :string
      add :emoji, :string
      add :tags, :string
      add :content, :map
      add :publish_at, :utc_datetime_usec
    end)

    create_versions(:page_versions, :page_id, :pages, fn ->
      add :title, :string
      add :slug, :string, null: false
      add :emoji, :string
      add :tags, :string
      add :content, :map
      add :page_type, :string, null: false
    end)

    create_versions(:project_versions, :project_id, :projects, fn ->
      add :title, :string, null: false
      add :slug, :string, null: false
      add :emoji, :string
      add :tags, :string
      add :content, :map
      add :short_description, :text, null: false
      add :company, :string
      add :role, :string
      add :period, :string
      add :started_at, :date, null: false
      add :ended_at, :date
      add :status, :string, null: false
      add :project_type, :string, null: false
      add :links, :map
    end)

    flush()

    backfill(:posts, :post_versions, :post_id, "WHERE draft = 0")
    backfill(:pages, :page_versions, :page_id)
    backfill(:projects, :project_versions, :project_id)
  end

  def down do
    for {table, versions} <- [
          posts: :post_versions,
          pages: :page_versions,
          projects: :project_versions
        ] do
      alter table(table) do
        remove :published_version_id
      end

      drop table(versions)
    end
  end

  # SQLite can add a column with a foreign key through ALTER TABLE as long
  # as it may be NULL, which published_version_id may be (a draft).
  defp create_versions(versions, owner, table, add_copied_columns) do
    create table(versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add owner, references(table, type: :binary_id, on_delete: :delete_all), null: false
      add :number, :integer, null: false
      add :published_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :published_at, :utc_datetime_usec, null: false

      add_copied_columns.()

      add :header_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)
      add :thumbnail_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)
    end

    create unique_index(versions, [owner, :number])

    alter table(table) do
      add :published_version_id,
          references(versions, type: :binary_id, on_delete: :nilify_all)
    end
  end

  # Version 1 holds each record's current state, published when it was last
  # saved; the publishing member is unknown.
  defp backfill(table, versions, owner, published_condition \\ "") do
    columns = Enum.join(@copied_columns[table], ", ")

    for [id] <- repo().query!("SELECT id FROM #{table}").rows do
      repo().query!(
        """
        INSERT INTO #{versions} (id, #{owner}, number, published_at, #{columns})
        SELECT ?1, id, 1, updated_at, #{columns} FROM #{table} WHERE id = ?2
        """,
        [Ecto.UUID.generate(), id]
      )
    end

    repo().query!("""
    UPDATE #{table}
    SET published_version_id =
      (SELECT v.id FROM #{versions} v WHERE v.#{owner} = #{table}.id AND v.number = 1)
    #{published_condition}
    """)
  end
end
