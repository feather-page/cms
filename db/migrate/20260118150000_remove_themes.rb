class RemoveThemes < ActiveRecord::Migration[7.2]
  def change
    remove_reference :sites, :theme, foreign_key: true

    drop_table :themes do |t|
      t.string :name, null: false
      t.string :public_id, limit: 21, null: false
      t.string :description
      t.string :hugo_theme, null: false
      t.timestamps

      t.index :public_id, unique: true
    end
  end
end
