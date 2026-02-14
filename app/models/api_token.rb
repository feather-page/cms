class ApiToken < ApplicationRecord
  belongs_to :user

  attr_reader :plain_token

  validates :token_digest, presence: true, uniqueness: true
  validates :name, length: { maximum: 255 }

  before_validation :generate_token, on: :create

  def self.authenticate(plain_token)
    return nil if plain_token.blank?

    find_by(token_digest: Digest::SHA256.hexdigest(plain_token))
  end

  private

  def generate_token
    return if token_digest.present?

    @plain_token = SecureRandom.hex(32)
    self.token_prefix = @plain_token[0, 8]
    self.token_digest = Digest::SHA256.hexdigest(@plain_token)
  end
end
