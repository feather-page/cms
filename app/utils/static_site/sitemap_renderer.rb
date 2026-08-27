require "builder"

module StaticSite
  # See ADR-006. Sitemap entries are addressed absolutely via
  # routes.canonical, by their external address.
  class SitemapRenderer
    def initialize(site:, routes:)
      @site = site
      @routes = routes.canonical
    end

    def render
      builder = Builder::XmlMarkup.new(indent: 2)
      builder.instruct! :xml, version: "1.0", encoding: "UTF-8"
      builder.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do |urlset|
        entries.each { |loc, lastmod| render_entry(urlset, loc, lastmod) }
      end
    end

    private

    attr_reader :site, :routes

    def entries
      home_entry + post_entries + page_entries + project_entries
    end

    # The home page lists published posts, so its freshness follows the most
    # recently changed one -- site.updated_at does not move when a post is
    # published.
    def home_entry
      [[routes.home_url, [published_posts.maximum(:updated_at), site.updated_at].compact.max]]
    end

    def published_posts
      @published_posts ||= site.posts.published
    end

    def post_entries
      published_posts.map { |post| [routes.post_url(post), post.updated_at] }
    end

    def page_entries
      site.pages.where.not(slug: "/").map { |page| [routes.page_url(page), page.updated_at] }
    end

    def project_entries
      site.projects.map { |project| [routes.project_url(project), project.updated_at] }
    end

    def render_entry(urlset, loc, lastmod)
      urlset.url do |url|
        url.loc loc
        url.lastmod lastmod.utc.iso8601
      end
    end
  end
end
