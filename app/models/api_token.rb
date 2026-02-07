class ApiToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :name, length: { maximum: 255 }

  before_validation :generate_token, on: :create

  private

  def generate_token
    self.token ||= SecureRandom.hex(32)
  end
end
