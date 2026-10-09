defmodule Feather.Repo.Migrations.AddLockVersionToContent do
  use Ecto.Migration

  # The counter the editor's autosave builds on: every save of a record
  # increments it, so a save based on an older state is rejected.
  def change do
    for table <- [:posts, :pages, :projects] do
      alter table(table) do
        add :lock_version, :integer, null: false, default: 1
      end
    end
  end
end
