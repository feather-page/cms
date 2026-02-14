# frozen_string_literal: true

class RestoreThemes < ActiveRecord::Migration[8.1]
  def up
    create_table :themes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :public_id, limit: 21, null: false
      t.string :description
      t.string :hugo_theme, null: false
      t.timestamps
    end

    add_index :themes, :public_id, unique: true
    add_index :themes, :hugo_theme, unique: true

    add_reference :sites, :theme, type: :uuid, foreign_key: true

    Theme.create!(name: "Simple Emoji", description: "A playful simple theme that supports emoji.", hugo_theme: "simple_emoji")

    Site.find_each do |site|
      site.update_column(:theme_id, Theme.first.id)
    end

    change_column_null :sites, :theme_id, false
  end

  def down
    remove_reference :sites, :theme, foreign_key: true
    drop_table :themes
  end
end
