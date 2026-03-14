module StaticSite
  class PageRenderer
    def render_home(site:, posts:, current_page:, total_pages:)
      render_template("static_site/home", home_assigns(site, posts, current_page, total_pages))
    end

    def render_post(site:, post:)
      render_template("static_site/post", post_assigns(site, post))
    end

    def render_page(site:, page:)
      render_template("static_site/page", page_assigns(site, page))
    end

    def render_project(site:, project:)
      render_template("static_site/project", project_assigns(site, project))
    end

    private

    def render_template(template, assigns)
      ApplicationController.render(template: template, layout: "static_site", assigns: assigns)
    end

    def home_assigns(site, posts, current_page, total_pages)
      base_assigns(site, site.title, site.emoji, true).merge(
        page: site.pages.find_by(slug: "/"),
        rss_url: "/feed.xml",
        posts: posts,
        current_page: current_page,
        total_pages: total_pages
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

    def project_assigns(site, project)
      base_assigns(site, project.title, project.emoji, false).merge(
        project: project,
        header_image: project.header_image
      )
    end

    def base_assigns(site, page_title, page_emoji, is_home)
      { site: site, page_title: page_title, page_emoji: page_emoji, is_home: is_home }
    end
  end
end
