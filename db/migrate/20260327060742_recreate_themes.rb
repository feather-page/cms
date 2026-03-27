class RecreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes, id: :uuid do |t|
      t.string :name, null: false
      t.string :hugo_theme, null: false
      t.string :public_id, limit: 21, null: false

      t.timestamps
    end

    add_index :themes, :hugo_theme, unique: true
    add_index :themes, :public_id, unique: true

    add_reference :sites, :theme, type: :uuid, foreign_key: true
  end
end
