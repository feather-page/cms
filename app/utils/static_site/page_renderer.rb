module StaticSite
  class PageRenderer
    POSTS_PER_PAGE = 25

    def render_home(site:, routes:, posts:, current_page:, total_pages:)
      render_template("static_site/home", home_assigns(site, routes, posts, current_page, total_pages))
    end

    def render_post(site:, routes:, post:)
      render_template("static_site/post", post_assigns(site, routes, post))
    end

    def render_page(site:, routes:, page:)
      render_template("static_site/page", page_assigns(site, routes, page))
    end

    def render_project(site:, routes:, project:)
      render_template("static_site/project", project_assigns(site, routes, project))
    end

    private

    def render_template(template, assigns)
      ApplicationController.render(template: template, layout: "static_site", assigns: assigns)
    end

    def home_assigns(site, routes, posts, current_page, total_pages)
      base_assigns(site, routes, site.title, site.emoji, true).merge(
        page: site.pages.find_by(slug: "/"),
        rss_url: "/feed.xml",
        posts: posts,
        current_page: current_page,
        total_pages: total_pages
      )
    end

    def post_assigns(site, routes, post)
      base_assigns(site, routes, post.title.presence || site.title, post.emoji, false).merge(
        post: post,
        header_image: post.header_image
      )
    end

    def page_assigns(site, routes, page)
      base_assigns(site, routes, page.title, page.emoji, false).merge(
        page: page,
        header_image: page.header_image
      )
    end

    def project_assigns(site, routes, project)
      base_assigns(site, routes, project.title, project.emoji, false).merge(
        project: project,
        header_image: project.header_image
      )
    end

    def base_assigns(site, routes, page_title, page_emoji, is_home)
      { site: site, routes: routes, page_title: page_title, page_emoji: page_emoji, is_home: is_home }
    end
  end
end
