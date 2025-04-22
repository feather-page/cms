class CreateJoinTableBookBookshelves < ActiveRecord::Migration[8.0]
  def change
    create_table :bookshelf_books, id: :uuid do |t|
      t.references :book, null: false, foreign_key: true, type: :uuid
      t.references :bookshelf, null: false, foreign_key: true, type: :uuid

      t.string :public_id, limit: 21

      t.index [:book_id, :bookshelf_id]
      t.index [:bookshelf_id, :book_id]

      t.timestamps
    end
  end
end
