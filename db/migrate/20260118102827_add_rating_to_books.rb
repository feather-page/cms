class AddRatingToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :rating, :integer
  end
end
