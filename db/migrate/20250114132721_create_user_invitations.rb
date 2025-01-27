class CreateUserInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_invitations, id: :uuid do |t|
      t.string :email
      t.string :public_id
      t.timestamp :accepted_at

      t.references :site, null: false, foreign_key: true, type: :uuid
      t.references :inviting_user, null: false, foreign_key: { to_table: :users, column: :id }, type: :uuid

      t.index :public_id, unique: true
      t.index :accepted_at

      t.index %i[email site_id], unique: true
      t.timestamps
    end
  end
end
