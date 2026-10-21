defmodule Feather.Repo.Migrations.AddAltToImages do
  use Ecto.Migration

  def change do
    alter table(:images) do
      add :alt, :text, null: false, default: ""
    end
  end
end
