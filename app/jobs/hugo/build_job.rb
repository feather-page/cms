require "open3"

module Hugo
  class BuildJob < ApplicationJob
    class HugoBuildError < StandardError; end
    class DeployLockError < StandardError; end

    LOCK_RETRY_LIMIT = 60
    LOCK_RETRY_WAIT = 5
    HUGO_TIMEOUT = 60

    queue_as :default

    def perform(deployment_target, preview: false)
      @deployment_target = deployment_target
      @site = deployment_target.site
      @preview = preview
      @build_path = deployment_target.source_path
      @lock_acquired = false

      unless preview
        acquire_lock!
        @lock_acquired = true
      end

      cleanup
      write_source_files
      run_hugo_build(output_path: output_path)
      unless preview
        precompress
        deploy
      end
    ensure
      deployment_target.release_deploy_lock! if @lock_acquired
    end

    private

    attr_reader :deployment_target, :site, :build_path

    def acquire_lock!
      LOCK_RETRY_LIMIT.times do
        return if deployment_target.acquire_deploy_lock!
        sleep(LOCK_RETRY_WAIT)
      end
      raise DeployLockError, "Could not acquire deploy lock after #{LOCK_RETRY_LIMIT} attempts"
    end

    def cleanup
      FileUtils.rm_rf(build_path)
      FileUtils.mkdir_p(build_path)
    end

    def write_source_files
      Hugo::ConfigFile.new(build_path: build_path, site: site, deployment_target: deployment_target).write

      write_content_files
      write_data_files
      write_image_files
      Hugo::ThemeLinker.link(build_path: build_path)
    end

    def write_content_files
      processor = StaticSite::ParallelProcessor.new(site.posts.published, thread_count: 4)
      processor.process { |post| Hugo::PostFile.new(build_path: build_path, post: post).write }

      processor = StaticSite::ParallelProcessor.new(site.pages.where.not(slug: "home"), thread_count: 4)
      processor.process { |page| Hugo::PageFile.new(build_path: build_path, page: page).write }

      # Homepage
      homepage = site.pages.find_by(slug: "home")
      Hugo::PageFile.new(build_path: build_path, page: homepage).write if homepage

      processor = StaticSite::ParallelProcessor.new(site.projects, thread_count: 4)
      processor.process { |project| Hugo::ProjectFile.new(build_path: build_path, project: project).write }
    end

    def write_data_files
      Hugo::DataFile.new(build_path: build_path, site: site, type: :books).write
      Hugo::DataFile.new(build_path: build_path, site: site, type: :projects).write
      Hugo::DataFile.new(build_path: build_path, site: site, type: :site).write
    end

    def write_image_files
      images = collect_images
      variants = images.flat_map { |image| Hugo::ImageVariant.all_for(image) }
      processor = StaticSite::ParallelProcessor.new(variants, thread_count: 4)
      processor.process do |variant|
        Hugo::ImageFile.new(build_path: build_path, image_variant: variant).write
      rescue => e
        Rails.logger.warn("Failed to write image variant #{variant.public_path}: #{e.message}")
      end
    end

    def collect_images
      images = site.images.assigned.to_a
      images += site.posts.published.filter_map(&:header_image)
      images += site.pages.filter_map(&:header_image)
      images += site.projects.filter_map(&:header_image)
      images += site.projects.filter_map(&:thumbnail_image)
      images += site.books.filter_map(&:cover_image)
      images.uniq
    end

    def run_hugo_build(output_path:)
      stdout, stderr, status = Open3.capture3(
        { "HOME" => Dir.home },
        "hugo",
        "--source", build_path.to_s,
        "--destination", output_path.to_s,
        "--minify",
        timeout: HUGO_TIMEOUT
      )
      unless status.success?
        Rails.logger.error("Hugo build failed (exit #{status.exitstatus}): #{stderr}")
        raise HugoBuildError, "Hugo build failed: #{stderr.truncate(500)}"
      end
      Rails.logger.info("Hugo build succeeded: #{stdout}")
    end

    def precompress
      StaticSite::PrecompressJob.perform_now(output_path.to_s)
    end

    def deploy
      Rclone::Deployer.deploy(deployment_target)
    end

    def output_path
      @preview ? deployment_target.preview_output_path : deployment_target.deploy_output_path
    end
  end
end
