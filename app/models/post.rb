class Post < ApplicationRecord
  include Editable

  belongs_to :site
  belongs_to :header_image, class_name: "Image", optional: true

  before_validation :normalize_slug
  before_validation :set_publish_at

  validates :slug, uniqueness: { scope: :site_id }, allow_blank: true
  validates :slug, format: { with: %r{\A/[a-z0-9-]+\z} }, allow_nil: true
  validates :emoji, emoji: true

  scope :latest, -> { order(publish_at: :desc) }
  scope :published, lambda {
    where(draft: false).where(publish_at: (..Time.current))
  }

  private

  def normalize_slug
    self.slug = nil if slug.blank?
  end

  def set_publish_at
    self.publish_at ||= Time.current
  end
end
