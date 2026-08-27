module StaticSite
  # See ADR-006.
  class Routes
    ARTIFACTS = %w[feed.xml robots.txt sitemap.xml].freeze
    RESERVED_PREFIXES = %w[images page posts projects].freeze

    include Resolution

    def self.for(deployment_target, as: :deployed)
      new(
        site: deployment_target.site,
        site_root: as == :preview ? "/preview/#{deployment_target.public_id}/" : "/",
        canonical_url: "https://#{deployment_target.public_hostname}/"
      )
    end

    attr_reader :site, :site_root, :canonical_url

    def initialize(site:, site_root: "/", canonical_url: nil)
      @site = site
      @site_root = site_root
      @canonical_url = canonical_url || site_root
    end

    def canonical
      return self if site_root == canonical_url

      @canonical ||= self.class.new(site:, site_root: canonical_url, canonical_url:)
    end

    def home_url(page: 1) = paginated?(page) ? "#{site_root}page/#{page.to_i}/" : site_root
    def post_url(post) = "#{site_root}#{post_segment(post)}/"
    def page_url(page) = page.homepage? ? home_url : "#{site_root}#{page_segment(page)}/"
    def project_url(project) = "#{site_root}#{project_segment(project)}/"
    def image_url(image, variant) = "#{site_root}#{image_segment(image, variant)}"
    def artifact_url(name) = "#{site_root}#{artifact(name)}"

    def home_path(page: 1) = paginated?(page) ? "page/#{page.to_i}/index.html" : "index.html"
    def post_path(post) = "#{post_segment(post)}/index.html"
    def page_path(page) = page.homepage? ? home_path : "#{page_segment(page)}/index.html"
    def project_path(project) = "#{project_segment(project)}/index.html"
    def image_path(image, variant) = image_segment(image, variant)
    def artifact_path(name) = artifact(name)

    private

    def paginated?(page) = page.to_i > 1

    def artifact(name)
      raise ArgumentError, "unknown artifact #{name.inspect}" unless ARTIFACTS.include?(name.to_s)

      name.to_s
    end

    def post_segment(post)
      post.slug.present? ? strip_slug(post.slug) : "posts/#{post.public_id.downcase}"
    end

    def page_segment(page) = strip_slug(page.slug)
    def project_segment(project) = "projects/#{strip_slug(project.slug)}"

    def image_segment(image, variant)
      "images/#{image.public_id}/#{Image::Variants.filename_for(variant)}"
    end

    def strip_slug(slug) = slug.to_s.delete_prefix("/").delete_suffix("/")
  end
end
