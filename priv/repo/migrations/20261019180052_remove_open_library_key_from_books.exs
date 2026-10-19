defmodule Feather.Repo.Migrations.RemoveOpenLibraryKeyFromBooks do
  use Ecto.Migration

  def change do
    alter table(:books) do
      remove :open_library_key, :string
    end
  end
end
