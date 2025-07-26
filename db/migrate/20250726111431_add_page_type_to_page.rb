class AddPageTypeToPage < ActiveRecord::Migration[8.0]
  def change
    add_column :pages, :page_type, :integer, default: 0, null: false
  end
end
