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

  def acquire_deploy_lock!
    reload
    return false if deploying?

    update!(deploying: true)
    true
  rescue ActiveRecord::StaleObjectError
    false
  end

  def release_deploy_lock!
    self.class.where(id: id).update_all(deploying: false, lock_version: 0)
  end

  def config
    JSON.parse(encrypted_config || "{}")
  end

  def config=(value)
    self.encrypted_config = value.to_json
  end

  def build_path
    Rails.root.join("storage", "hugo", id.to_s)
  end

  def source_path
    build_path.join("source")
  end

  def deploy_output_path
    build_path.join("deploy")
  end

  def preview_output_path
    build_path.join("preview")
  end

  def source_dir
    "#{deploy_output_path}/"
  end
end
