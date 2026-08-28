module StaticSite
  # Renders a whole site into a sink. Knows nothing about deployment targets,
  # locks or where the files end up — see docs/adr/0006-export-writes-through-a-sink.md.
  class Export
    THREAD_COUNT = 4

    def initialize(site:, routes:, sink:)
      @site = site
      @routes = routes
      @sink = sink
    end

    def run
      export_home
      export_posts
      export_projects
      export_pages
      export_images
      export_rss_feed
      export_robots_txt
      export_sitemap
    end

    private

    attr_reader :site, :routes, :sink

    def export_home
      posts = site.posts.published.order(publish_at: :desc).to_a
      per_page = PageRenderer::POSTS_PER_PAGE
      total_pages = [(posts.length / per_page.to_f).ceil, 1].max

      (1..total_pages).each do |page_number|
        page_posts = posts.slice((page_number - 1) * per_page, per_page) || []
        sink.write(
          routes.home_path(page: page_number),
          render_home_page(page_posts, page_number, total_pages)
        )
      end
    end

    def render_home_page(posts, current_page, total_pages)
      renderer.render_home(
        site: site, routes: routes, posts: posts,
        current_page: current_page, total_pages: total_pages
      )
    end

    def export_posts
      in_parallel(site.posts.published.to_a) do |post, thread_renderer|
        sink.write(routes.post_path(post), thread_renderer.render_post(site: site, routes: routes, post: post))
      end
    end

    def export_projects
      in_parallel(site.projects.ordered.to_a) do |project, thread_renderer|
        sink.write(
          routes.project_path(project),
          thread_renderer.render_project(site: site, routes: routes, project: project)
        )
      end
    end

    def export_pages
      in_parallel(site.pages.where.not(slug: "/").to_a) do |page, thread_renderer|
        sink.write(routes.page_path(page), thread_renderer.render_page(site: site, routes: routes, page: page))
      end
    end

    def export_images
      images = ImageCollector.new(site).to_a
      image_variants = images.flat_map { |img| Image::Variants.keys.map { |key| [img, key] } }
      ParallelProcessor.new(image_variants, thread_count: THREAD_COUNT).process do |(image, variant_key)|
        copy_image_variant(image, variant_key)
      end
    end

    def copy_image_variant(image, variant_key)
      source_path = image.fs_path(variant: variant_key)
      return unless source_path && File.exist?(source_path)

      sink.copy(routes.image_path(image, variant_key), from: source_path)
    end

    def export_rss_feed
      sink.write(routes.artifact_path("feed.xml"), RssFeedRenderer.new(site: site, routes: routes).render)
    end

    def export_robots_txt
      sink.write(routes.artifact_path("robots.txt"), robots_content)
    end

    def robots_content
      "User-agent: *\nAllow: /\n\nSitemap: #{routes.canonical.artifact_url('sitemap.xml')}\n"
    end

    def export_sitemap
      sink.write(routes.artifact_path("sitemap.xml"), SitemapRenderer.new(site: site, routes: routes).render)
    end

    # Each thread renders through its own PageRenderer; ApplicationController.render
    # is not safe to share across threads.
    def in_parallel(records)
      ParallelProcessor.new(records, thread_count: THREAD_COUNT).process do |record|
        yield record, PageRenderer.new
      end
    end

    def renderer
      @renderer ||= PageRenderer.new
    end
  end
end
