# frozen_string_literal: true

class CreateApiTokens < ActiveRecord::Migration[8.1]
  def up
    create_table :api_tokens, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :token, null: false
      t.string :name
      t.string :public_id, limit: 21, null: false
      t.uuid :user_id, null: false

      t.timestamps
    end

    add_index :api_tokens, :token, unique: true
    add_index :api_tokens, :public_id, unique: true
    add_index :api_tokens, :user_id
    add_foreign_key :api_tokens, :users
  end

  def down
    drop_table :api_tokens
  end
end
