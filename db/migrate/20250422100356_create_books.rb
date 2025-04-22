class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :books, id: :uuid do |t|
      t.string :public_id, limit: 21
      t.string :title
      t.references :author, null: false, foreign_key: true, type: :uuid
      t.string :open_library_id

      t.index :public_id, unique: true
      t.index :open_library_id, unique: true

      t.timestamps
    end
  end
end
