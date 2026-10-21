defmodule Feather.Repo.Migrations.AddNotificationKeysToSites do
  use Ecto.Migration

  def up do
    alter table(:sites) do
      add :indexnow_key, :string
      add :archive_org_keys, :binary
    end

    flush()

    execute "UPDATE sites SET indexnow_key = lower(hex(randomblob(16))) WHERE indexnow_key IS NULL"
  end

  def down do
    alter table(:sites) do
      remove :indexnow_key
      remove :archive_org_keys
    end
  end
end
