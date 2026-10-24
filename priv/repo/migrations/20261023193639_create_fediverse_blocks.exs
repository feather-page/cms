defmodule Feather.Repo.Migrations.CreateFediverseBlocks do
  use Ecto.Migration

  def change do
    create table(:fediverse_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :account_uri, :string
      add :handle, :string
      add :host, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_blocks, [:site_id, :account_uri])
    create unique_index(:fediverse_blocks, [:site_id, :host])
  end
end
