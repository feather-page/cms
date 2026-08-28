module Sluggable
  extend ActiveSupport::Concern

  SLUG_FORMAT = %r{\A/([a-z0-9-]+(/[a-z0-9-]+)*)?\z}

  included do
    before_validation :normalize_slug
    validates :slug, format: { with: SLUG_FORMAT }, allow_nil: true
    validate :slug_is_not_root, unless: :root_slug_allowed?
    validate :slug_is_not_reserved, unless: :slug_in_own_namespace?
  end

  # Only the homepage may address the site root; everything else would
  # overwrite index.html on export.
  def root_slug_allowed? = false

  def slug_in_own_namespace? = false

  private

  def normalize_slug
    self.slug = nil if slug.blank?
    return if slug.nil?

    self.slug = "/#{slug.delete_prefix('/').delete_suffix('/')}"
  end

  def slug_is_not_root
    errors.add(:slug, :root_reserved) if slug == "/"
  end

  def slug_is_not_reserved
    return if slug.blank?

    errors.add(:slug, :reserved) if StaticSite::Routes.reserved?(slug)
  end
end
