class AddHeaderImageSupport < ActiveRecord::Migration[8.1]
  def change
    add_reference :posts, :header_image, foreign_key: { to_table: :images }, type: :uuid
    add_reference :pages, :header_image, foreign_key: { to_table: :images }, type: :uuid
    add_column :images, :unsplash_data, :jsonb
    add_index :images, :unsplash_data, using: :gin
  end
end
