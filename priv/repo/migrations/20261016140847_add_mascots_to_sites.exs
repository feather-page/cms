defmodule Feather.Repo.Migrations.AddMascotsToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :footer_mascot_image_id,
          references(:images, type: :binary_id, on_delete: :nilify_all)

      add :post_end_mascot_image_id,
          references(:images, type: :binary_id, on_delete: :nilify_all)

      add :projects_mascot_image_id,
          references(:images, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
