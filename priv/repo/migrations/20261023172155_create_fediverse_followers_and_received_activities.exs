defmodule Feather.Repo.Migrations.CreateFediverseFollowersAndReceivedActivities do
  use Ecto.Migration

  def change do
    create table(:fediverse_followers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false

      add :remote_account_id,
          references(:fediverse_remote_accounts, type: :binary_id, on_delete: :delete_all),
          null: false

      add :follow_id, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_followers, [:site_id, :remote_account_id])
    create index(:fediverse_followers, [:remote_account_id])

    create table(:fediverse_received_activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false

      add :remote_account_id,
          references(:fediverse_remote_accounts, type: :binary_id, on_delete: :delete_all),
          null: false

      add :activity_id, :string, null: false
      add :payload, :binary
      add :attempts, :integer, null: false, default: 0
      add :next_attempt_at, :utc_datetime_usec
      add :claimed_until, :utc_datetime_usec
      add :processed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_received_activities, [
             :site_id,
             :remote_account_id,
             :activity_id
           ])

    create index(:fediverse_received_activities, [:remote_account_id])
    create index(:fediverse_received_activities, [:next_attempt_at])
  end
end
