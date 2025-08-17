class DeploymentTarget < ApplicationRecord
  self.inheritance_column = 'sti_type'

  belongs_to :site

  encrypts :config

  validates :public_hostname, presence: true, uniqueness: true
  validates :provider, presence: true, inclusion: { in: Rclone::PROVIDERS.keys.map(&:to_s) }
  validates :type, presence: true

  enum :type, { staging: 0, production: 1, backup: 2 }

  normalizes :public_hostname, with: ->(hostname) { hostname.strip.downcase }

  scope :non_backup, -> { where.not(type: :backup) }
  scope :interal, -> { where(provider: :internal) }

  def deploy
    Hugo::BuildJob.perform_later(self)
  end

  def config
    JSON.load(encrypted_config || "{}")
  end

  def config=(value)
    self.encrypted_config = value.to_json
  end

  def build_path
    Rails.root.join("tmp", "hugo", id).to_s
  end

  def source_dir
    "#{build_path}/public/"
  end
end
