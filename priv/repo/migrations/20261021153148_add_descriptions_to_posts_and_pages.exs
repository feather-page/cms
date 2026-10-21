defmodule Feather.Repo.Migrations.AddDescriptionsToPostsAndPages do
  use Ecto.Migration

  def change do
    for table <- [:posts, :post_versions, :pages, :page_versions] do
      alter table(table) do
        add :description, :text
        add :description_generated, :boolean, null: false, default: false
      end
    end
  end
end
