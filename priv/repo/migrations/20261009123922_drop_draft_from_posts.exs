defmodule Feather.Repo.Migrations.DropDraftFromPosts do
  use Ecto.Migration

  # A post without a published version is a draft (ADR-0011).
  def up do
    alter table(:posts) do
      remove :draft
    end
  end

  def down do
    alter table(:posts) do
      add :draft, :boolean, null: false, default: false
    end

    execute "UPDATE posts SET draft = 1 WHERE published_version_id IS NULL"
  end
end
