module StaticSite
  class PageRenderer
    def render_home(site:)
      render_template("static_site/home", home_assigns(site))
    end

    def render_post(site:, post:)
      render_template("static_site/post", post_assigns(site, post))
    end

    def render_page(site:, page:)
      render_template("static_site/page", page_assigns(site, page))
    end

    private

    def render_template(template, assigns)
      ApplicationController.render(template: template, layout: "static_site", assigns: assigns)
    end

    def home_assigns(site)
      base_assigns(site, site.title, site.emoji, true).merge(
        page: site.pages.find_by(slug: "/"),
        rss_url: "/feed.xml"
      )
    end

    def post_assigns(site, post)
      base_assigns(site, post.title.presence || site.title, post.emoji, false).merge(
        post: post,
        header_image: post.header_image
      )
    end

    def page_assigns(site, page)
      base_assigns(site, page.title, page.emoji, false).merge(
        page: page,
        header_image: page.header_image
      )
    end

    def base_assigns(site, page_title, page_emoji, is_home)
      { site: site, page_title: page_title, page_emoji: page_emoji, is_home: is_home }
    end
  end
end
