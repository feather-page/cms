module PreviewRouting
  extend ActiveSupport::Concern

  private

  def preview_route_type
    return :home if home_path?
    return :image if image_path?
    return :post if post_path?
    return :page if page_path?
    return :post if slug_matches_post?

    :not_found
  end

  def home_path?
    requested_path.blank? || requested_path == "index.html" || requested_path == "index"
  end

  def image_path?
    requested_path.start_with?("images/")
  end

  def post_path?
    requested_path.start_with?("posts/") && find_post_by_path.present?
  end

  def page_path?
    find_page_by_path.present?
  end

  def slug_matches_post?
    find_post_by_slug.present?
  end

  def find_post_by_path
    return unless requested_path.start_with?("posts/")

    public_id = extract_post_public_id
    site.posts.find_by("LOWER(public_id) = ?", public_id.downcase)
  end

  def find_post_by_slug
    slug = "/#{requested_path.sub(%r{/$}, '')}"
    site.posts.find_by(slug: slug)
  end

  def find_page_by_path
    slug = normalize_page_slug
    site.pages.find_by(slug: slug)
  end

  def extract_post_public_id
    requested_path.sub(%r{^posts/}, "").sub(%r{/$}, "").sub(/\.html$/, "")
  end

  def normalize_page_slug
    slug = "/#{requested_path.sub(%r{/$}, '').sub(/\.html$/, '')}"
    slug == "/index" ? "/" : slug
  end
end
