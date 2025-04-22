class CreateBookshelves < ActiveRecord::Migration[8.0]
  def change
    create_table :bookshelves, id: :uuid do |t|
      t.string :public_id, limit: 21

      t.references :site, null: false, foreign_key: true, type: :uuid
      t.string :name

      t.index :public_id, unique: true

      t.index %i[name site_id], unique: true
      t.timestamps
    end
  end
end
