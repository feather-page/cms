class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.string :public_id, limit: 21, null: false
      t.references :site, null: false, foreign_key: true, type: :uuid
      t.references :header_image, foreign_key: { to_table: :images }, type: :uuid

      t.string :title, null: false
      t.string :slug, null: false
      t.string :company
      t.string :period                      # Display: "März 2019 - August 2020"
      t.date :started_at, null: false       # For sorting
      t.date :ended_at                      # nil = ongoing
      t.integer :status, default: 0         # enum
      t.string :role
      t.text :short_description, null: false
      t.json :content                       # EditorJS
      t.integer :project_type               # enum
      t.json :links                         # [{label, url}]
      t.string :emoji

      t.index :public_id, unique: true
      t.index [:slug, :site_id], unique: true
      t.index :started_at

      t.timestamps
    end
  end
end
