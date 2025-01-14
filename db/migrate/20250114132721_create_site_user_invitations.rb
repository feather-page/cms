class CreateSiteUserInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :site_user_invitations, id: :uuid do |t|
      t.string :email
      t.references :site, null: false, foreign_key: true, type: :uuid
      t.references :inviting_user, null: false, foreign_key: { to_table: :users, column: :id }, type: :uuid

      t.timestamps
    end
  end
end
