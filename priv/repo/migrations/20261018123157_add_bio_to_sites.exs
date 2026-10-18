defmodule Feather.Repo.Migrations.AddBioToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :bio, :text
    end
  end
end
