defmodule Feather.Repo.Migrations.AddFediverseToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :fediverse_name, :string
      add :fediverse_public_key, :text
      add :fediverse_private_key, :binary
      add :fediverse_pending_public_key, :text
      add :fediverse_pending_private_key, :binary
      add :fediverse_online_at, :utc_datetime_usec
    end
  end
end
