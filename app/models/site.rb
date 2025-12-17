class Site < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :pages, dependent: :destroy
  has_many :images, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :site_users, dependent: :destroy
  has_many :social_media_links, dependent: :destroy
  has_many :users, through: :site_users
  has_many :deployment_targets, dependent: :destroy
  has_many :navigations, dependent: :destroy
  has_many :user_invitations, dependent: :destroy

  belongs_to :theme

  validates :title, presence: true
  validates :language_code, presence: true, inclusion: { in: Form::LanguageSelectComponent::Codes::ISO_CODES }
  validates :domain, presence: true, format: { with: /\A[a-zA-Z0-9\-.]+\z/ }
  validates :emoji, emoji: true
  validates :copyright, presence: true

  def publish(to: :staging)
    deployment_targets.where(type: to.to_s).find_each(&:deploy)
  end

  def summary_length
    30
  end

  def main_navigation
    navigations.first || navigations.create!
  end
end
