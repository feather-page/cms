module StaticSite
  class ExportJob < ApplicationJob
    include OutputPaths

    queue_as :default

    def perform(deployment_target)
      @deployment_target = deployment_target
      @site = deployment_target.site

      cleanup
      export_content
      precompress
      deploy
    end

    private

    attr_reader :deployment_target, :site

    def cleanup
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
    end

    def export_content
      export_home
      export_posts
      export_pages
      export_images
      export_rss_feed
      export_robots_txt
    end

    def export_home
      write_file("index.html", renderer.render_home(site: site))
    end

    def export_posts
      site.posts.published.find_each do |post|
        write_file(post_output_path(post), renderer.render_post(site: site, post: post))
      end
    end

    def export_pages
      site.pages.where.not(slug: "/").find_each do |page|
        write_file(page_output_path(page), renderer.render_page(site: site, page: page))
      end
    end

    def export_images
      ImageCollector.new(site).to_a.each { |image| export_image_variants(image) }
    end

    def export_image_variants(image)
      Image::Variants.each_key { |key| copy_image_variant(image, key) }
    end

    def copy_image_variant(image, variant_key)
      source_path = image.fs_path(variant: variant_key)
      return unless source_path && File.exist?(source_path)

      dest_path = File.join(output_dir, image_output_path(image, variant_key))
      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.cp(source_path, dest_path)
    end

    def export_rss_feed
      write_file("feed.xml", RssFeedRenderer.new(site: site, base_url: base_url).render)
    end

    def export_robots_txt
      write_file("robots.txt", robots_content)
    end

    def robots_content
      "User-agent: *\nAllow: /\n\nSitemap: #{base_url}sitemap.xml\n"
    end

    def precompress
      PrecompressJob.perform_now(output_dir)
    end

    def deploy
      Rclone::DeployJob.perform_later(deployment_target)
    end

    def renderer
      @renderer ||= PageRenderer.new
    end

    def output_dir
      @output_dir ||= deployment_target.source_dir
    end

    def write_file(relative_path, content)
      full_path = File.join(output_dir, relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end

    def base_url
      deployment_target.provider == "internal" ? "/preview/#{deployment_target.id}/" : "https://#{deployment_target.public_hostname}/"
    end
  end
end
