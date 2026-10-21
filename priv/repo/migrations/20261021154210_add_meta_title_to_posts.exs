defmodule Feather.Repo.Migrations.AddMetaTitleToPosts do
  use Ecto.Migration

  def change do
    for table <- [:posts, :post_versions] do
      alter table(table) do
        add :meta_title, :text
      end
    end
  end
end
