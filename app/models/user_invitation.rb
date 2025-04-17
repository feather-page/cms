class UserInvitation < ApplicationRecord
  belongs_to :site
  belongs_to :inviting_user, class_name: 'User'

  validates :email, uniqueness: { scope: :site_id }
  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :user_is_not_already_part_of_site

  generates_token_for :accept_invitation, expires_in: 7.days

  scope :pending, -> { where(accepted_at: nil) }

  def accepted?
    accepted_at.present?
  end

  def accept_invitation_token
    generate_token_for(:accept_invitation)
  end

  private

  def user_is_not_already_part_of_site
    return unless site.site_users.joins(:user).exists?(users: { email: email })

    errors.add(:email, :already_site_user)
  end
end
