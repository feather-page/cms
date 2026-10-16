defmodule Feather.Repo.Migrations.AddThemeAndPortraitToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :theme, :string, null: false, default: "feather"
      add :portrait_image_id, references(:images, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
