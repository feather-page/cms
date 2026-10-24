defmodule Feather.Repo.Migrations.AddFediverseGenerationToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :fediverse_generation, :integer, null: false, default: 1
    end
  end
end
