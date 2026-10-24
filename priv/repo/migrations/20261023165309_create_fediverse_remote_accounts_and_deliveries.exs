defmodule Feather.Repo.Migrations.CreateFediverseRemoteAccountsAndDeliveries do
  use Ecto.Migration

  def change do
    create table(:fediverse_remote_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :string, null: false
      add :host, :string, null: false
      add :key_id, :string, null: false
      add :public_key, :text, null: false
      add :name, :string
      add :handle, :string
      add :picture_url, :string
      add :inbox, :string, null: false
      add :shared_inbox, :string
      add :fetched_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_remote_accounts, [:uri])

    create table(:fediverse_deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :inbox, :string, null: false
      add :host, :string, null: false
      add :payload, :binary, null: false
      add :attempts, :integer, null: false, default: 0
      add :next_attempt_at, :utc_datetime_usec, null: false
      add :claimed_until, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:fediverse_deliveries, [:site_id])
    create index(:fediverse_deliveries, [:next_attempt_at])
    create index(:fediverse_deliveries, [:host])
  end
end
