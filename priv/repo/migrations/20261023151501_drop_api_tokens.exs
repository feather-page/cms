defmodule Feather.Repo.Migrations.DropApiTokens do
  use Ecto.Migration

  def up do
    drop table(:api_tokens)
  end

  # Brings back the empty table; the dropped tokens are gone.
  def down do
    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string
      add :token_digest, :string, null: false
      add :token_prefix, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:api_tokens, [:user_id])
    create unique_index(:api_tokens, [:token_digest])
  end
end
