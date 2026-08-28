class SlugGenerator
  def initialize(site)
    @site = site
  end

  def generate(slug, attempts = 0)
    slug = slug.delete('/')
    slug = slug.downcase.strip
    slug = slug.gsub(/[^a-z0-9-]/i, '-').squeeze('-')
    return slug if slug.blank?

    slug = "/#{slug}"
    alternative_slug = attempts.zero? ? slug : "#{slug}#{attempts}"
    return alternative_slug unless taken?(alternative_slug)

    generate(slug, attempts + 1)
  end

  private

  def taken?(slug)
    slug_exists?(slug) || reserved?(slug)
  end

  def slug_exists?(slug)
    @site.posts.exists?(slug:) || @site.pages.exists?(slug:)
  end

  # Reserved slugs are rejected by Sluggable, so never suggest one.
  def reserved?(slug)
    StaticSite::Routes.reserved?(slug)
  end
end
