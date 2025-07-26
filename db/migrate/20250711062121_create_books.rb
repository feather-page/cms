class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :books, id: :uuid do |t|
      t.string :public_id

      t.references :site, null: false, foreign_key: true, type: :uuid
      t.references :post, foreign_key: true, type: :uuid

      t.string :title, null: false
      t.string :author, null: false
      t.datetime :read_at, null: false
      t.string :emoji

      t.index :public_id, unique: true

      t.timestamps
    end
  end
end
