# frozen_string_literal: true

require "rails_helper"

RSpec.describe Hugo::BuildJob do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site: site) }
  let(:shell) { class_double(ShellCommand, run: nil) }
  let(:compressor) { class_double(StaticSite::PrecompressJob, perform_now: nil) }
  let(:deploy_job) { class_double(Rclone::DeployJob, perform_later: nil) }

  after do
    FileUtils.rm_rf(deployment_target.build_path)
  end

  describe "#perform" do
    it "creates the build directory" do
      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      expect(Dir.exist?(deployment_target.build_path)).to be true
    end

    it "writes config.json" do
      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      config_path = File.join(deployment_target.build_path, "config.json")
      expect(File.exist?(config_path)).to be true

      config = JSON.parse(File.read(config_path))
      expect(config["title"]).to eq(site.title)
      expect(config["theme"]).to eq(site.theme.hugo_theme)
    end

    it "writes post files" do
      create(:post, site: site, title: "Test Post", publish_at: 1.day.ago)

      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      post_files = Dir.glob(File.join(deployment_target.build_path, "content/posts/*.html"))
      expect(post_files.length).to eq(1)
    end

    it "writes page files" do
      create(:page, site: site, title: "About", slug: "/about")

      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      page_files = Dir.glob(File.join(deployment_target.build_path, "content/pages/*.html"))
      expect(page_files.length).to eq(1)
    end

    it "writes project files" do
      create(:project, site: site, title: "My Project", slug: "my-project")

      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      project_files = Dir.glob(File.join(deployment_target.build_path, "content/projects/*.html"))
      expect(project_files.length).to eq(1)
    end

    it "writes robots.txt" do
      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      robots_path = File.join(deployment_target.build_path, "content/robots.txt")
      expect(File.exist?(robots_path)).to be true
    end

    it "symlinks themes directory" do
      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      themes_path = File.join(deployment_target.build_path, "themes")
      expect(File.symlink?(themes_path)).to be true
    end

    it "runs the hugo command" do
      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      expect(shell).to have_received(:run).with(["hugo"], chdir: deployment_target.build_path, log: true)
    end

    it "calls precompress on the source directory" do
      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      expect(compressor).to have_received(:perform_now).with(deployment_target.source_dir)
    end

    it "triggers deployment" do
      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      expect(deploy_job).to have_received(:perform_later).with(deployment_target)
    end

    it "cleans up before building" do
      old_file = File.join(deployment_target.build_path, "old_file.txt")
      FileUtils.mkdir_p(deployment_target.build_path)
      File.write(old_file, "old content")

      described_class.perform_now(deployment_target, shell: shell, compressor: compressor, deployment_job: deploy_job)

      expect(File.exist?(old_file)).to be false
    end
  end
end
