defmodule Feather.Repo.Migrations.CreateAuthorizationCodesAndConnectedApps do
  use Ecto.Migration

  def change do
    create table(:authorization_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :code_digest, :string, null: false
      add :client_id, :string, null: false
      add :client_name, :string, null: false
      add :redirect_uri, :string, null: false
      add :code_challenge, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:authorization_codes, [:user_id])
    create unique_index(:authorization_codes, [:code_digest])

    create table(:connected_apps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :client_id, :string, null: false
      add :client_name, :string, null: false
      add :access_token_digest, :string, null: false
      add :access_token_expires_at, :utc_datetime_usec, null: false
      add :refresh_token_digest, :string, null: false
      add :last_used_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:connected_apps, [:user_id])
    create unique_index(:connected_apps, [:access_token_digest])
    create unique_index(:connected_apps, [:refresh_token_digest])
  end
end
