module Sluggable
  extend ActiveSupport::Concern

  SLUG_FORMAT = %r{\A/([a-z0-9-]+(/[a-z0-9-]+)*)?\z}

  included do
    before_validation :normalize_slug
    validates :slug, format: { with: SLUG_FORMAT }, allow_nil: true
    validate :slug_is_not_reserved, unless: :slug_in_own_namespace?
  end

  # Projects live under projects/ and cannot collide with generated paths.
  def slug_in_own_namespace? = false

  private

  def normalize_slug
    self.slug = nil if slug.blank?
    return if slug.nil?

    self.slug = "/#{slug.delete_prefix('/').delete_suffix('/')}"
  end

  def slug_is_not_reserved
    return if slug.blank?

    errors.add(:slug, :reserved) if reserved_slug?
  end

  def reserved_slug?
    path = slug.delete_prefix("/")

    StaticSite::Routes::RESERVED_PREFIXES.include?(path.split("/").first) ||
      StaticSite::Routes::ARTIFACTS.include?(path)
  end
end
