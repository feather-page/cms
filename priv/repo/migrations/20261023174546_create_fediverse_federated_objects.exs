defmodule Feather.Repo.Migrations.CreateFediverseFederatedObjects do
  use Ecto.Migration

  def change do
    create table(:fediverse_federated_objects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :post_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :uri, :string, null: false
      add :document_hash, :string, null: false
      add :document_updated_at, :utc_datetime
      add :deleted, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fediverse_federated_objects, [:site_id, :uri])
    create index(:fediverse_federated_objects, [:post_id])
  end
end
