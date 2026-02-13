class AddTagsToPostsPagesAndProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :tags, :string
    add_column :pages, :tags, :string
    add_column :projects, :tags, :string
  end
end
