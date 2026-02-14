class HashApiTokens < ActiveRecord::Migration[8.1]
  def up
    add_column :api_tokens, :token_prefix, :string, limit: 8

    execute "UPDATE api_tokens SET token_prefix = substring(token from 1 for 8)"
    execute <<~SQL.squish
      UPDATE api_tokens
      SET token = encode(sha256(convert_to(token, 'UTF8')), 'hex')
    SQL

    rename_column :api_tokens, :token, :token_digest
    change_column_null :api_tokens, :token_prefix, false
  end

  def down
    rename_column :api_tokens, :token_digest, :token
    remove_column :api_tokens, :token_prefix
  end
end
