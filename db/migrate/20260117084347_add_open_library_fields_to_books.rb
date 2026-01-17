class AddOpenLibraryFieldsToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :reading_status, :integer, default: 2, null: false
    add_column :books, :isbn, :string
    add_column :books, :open_library_key, :string

    add_index :books, :reading_status

    change_column_null :books, :read_at, true
  end
end
