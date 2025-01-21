class UserInvitation < ApplicationRecord
  belongs_to :site
  belongs_to :inviting_user, class_name: 'User'

  validates :email, uniqueness: { scope: :site_id }
  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  generates_token_for :accept_invitation, expires_in: 7.days

  def to_param
    generate_token_for(:accept_invitation)
  end
end
