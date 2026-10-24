defmodule Feather.Repo.Migrations.AddApprovalToFediverseMentions do
  use Ecto.Migration

  def change do
    alter table(:fediverse_mentions) do
      add :approval, :string, null: false, default: "waiting"
      add :approved_at, :utc_datetime_usec
      add :approved_content, :binary
      add :approved_name, :string
      add :approved_handle, :string
      add :approved_picture, :string
    end

    create index(:fediverse_mentions, [:site_id, :approval])

    create table(:fediverse_unused_pictures, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:fediverse_unused_pictures, [:site_id])

    create table(:fediverse_tombstones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :uri, :string, null: false
      add :author, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:fediverse_tombstones, [:site_id, :uri, :author])
  end
end
