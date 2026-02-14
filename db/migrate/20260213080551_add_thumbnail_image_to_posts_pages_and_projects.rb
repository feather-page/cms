class AddThumbnailImageToPostsPagesAndProjects < ActiveRecord::Migration[8.1]
  def change
    add_reference :posts, :thumbnail_image, foreign_key: { to_table: :images }, type: :uuid
    add_reference :pages, :thumbnail_image, foreign_key: { to_table: :images }, type: :uuid
    add_reference :projects, :thumbnail_image, foreign_key: { to_table: :images }, type: :uuid
  end
end
