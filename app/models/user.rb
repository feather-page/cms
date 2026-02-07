class User < ApplicationRecord
  has_many :api_tokens, dependent: :destroy
  has_many :site_users, dependent: :destroy
  has_many :sites, through: :site_users

  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :email_login, expires_in: 30.minutes do
    last_login_at
  end
end
