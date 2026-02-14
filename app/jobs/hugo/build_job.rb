# frozen_string_literal: true

module Hugo
  class BuildJob < ApplicationJob
    queue_as :default

    def perform(deployment_target, shell: ShellCommand,
                compressor: StaticSite::PrecompressJob,
                deployment_job: Rclone::DeployJob)
      @deployment_target = deployment_target
      @site = deployment_target.site

      cleanup
      write_files
      symlink_themes
      run_hugo(shell)

      compressor.perform_now(deployment_target.source_dir)
      deployment_job.perform_later(deployment_target)
    end

    private

    attr_reader :deployment_target, :site

    def cleanup
      FileUtils.rm_rf(deployment_target.build_path)
      FileUtils.mkdir_p(deployment_target.build_path)
    end

    def write_files
      files = []
      files << Hugo::ConfigFile.new(site, deployment_target)
      files += post_files
      files += page_files
      files += project_files
      files << Hugo::RobotsTxtFile.new(deployment_target)
      files += image_files

      files.each(&:write)
    end

    def post_files
      site.posts.published.map { |post| Hugo::PostFile.new(post, deployment_target) }
    end

    def page_files
      site.pages.map { |page| Hugo::PageFile.new(page, deployment_target) }
    end

    def project_files
      site.projects.ordered.map { |project| Hugo::ProjectFile.new(project, deployment_target) }
    end

    def image_files
      all_images.flat_map do |image|
        Image::Variants.keys.filter_map do |variant|
          next unless image.fs_path(variant: variant)&.then { |p| File.exist?(p) }

          image_variant = Hugo::ImageVariant.new(image, variant)
          Hugo::ImageFile.new(image_variant, deployment_target)
        end
      end
    end

    def all_images
      StaticSite::ImageCollector.new(site).to_a
    end

    def symlink_themes
      theme_path = Rails.root.join("vendor/themes")
      target = File.join(deployment_target.build_path, "themes")
      FileUtils.ln_s(theme_path, target) unless File.exist?(target)
    end

    def run_hugo(shell)
      shell.run(["hugo"], chdir: deployment_target.build_path, log: true)
    end
  end
end
