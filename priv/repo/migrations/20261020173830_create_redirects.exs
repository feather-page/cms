defmodule Feather.Repo.Migrations.CreateRedirects do
  use Ecto.Migration

  def change do
    create table(:redirects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :site_id, references(:sites, type: :binary_id, on_delete: :delete_all), null: false
      add :old_path, :string, null: false
      add :kind, :string, null: false, default: "permanent"
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :page_id, references(:pages, type: :binary_id, on_delete: :delete_all)
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all)

      add :target_path, :string,
        check: %{
          name: "redirects_one_target",
          expr:
            "(post_id IS NOT NULL) + (page_id IS NOT NULL) + (project_id IS NOT NULL) + (target_path IS NOT NULL) = 1"
        }

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:redirects, [:public_id])
    create unique_index(:redirects, [:site_id, :old_path])
    create index(:redirects, [:post_id])
    create index(:redirects, [:page_id])
    create index(:redirects, [:project_id])
  end
end
