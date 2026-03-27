require "rails_helper"

RSpec.describe Hugo::BuildJob do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }

  let(:hugo_success_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }
  let(:hugo_failure_status) { instance_double(Process::Status, success?: false, exitstatus: 1) }

  before do
    allow(Open3).to receive(:capture3).and_return(["Build complete", "", hugo_success_status])
    allow(StaticSite::PrecompressJob).to receive(:perform_now)
    allow(Rclone::Deployer).to receive(:deploy)
  end

  after do
    FileUtils.rm_rf(deployment_target.build_path)
  end

  def perform(preview: false)
    described_class.perform_now(deployment_target, preview:)
  end

  describe "#perform" do
    it "writes config.json to source path" do
      perform

      config_path = deployment_target.source_path.join("config.json")
      expect(config_path).to exist
      config = JSON.parse(File.read(config_path))
      expect(config["title"]).to eq(site.title)
    end

    it "writes content files for published posts" do
      post = create(:post, site:, publish_at: 1.day.ago)

      perform

      post_path = deployment_target.source_path.join("content/posts/#{post.slug}.html").cleanpath
      expect(post_path).to exist
    end

    it "does not write draft posts" do
      draft = create(:post, site:, draft: true)

      perform

      post_path = deployment_target.source_path.join("content/posts/#{draft.slug}.html").cleanpath
      expect(post_path).not_to exist
    end

    it "writes page files" do
      page = create(:page, site:, slug: "about")

      perform

      page_path = deployment_target.source_path.join("content", "pages", "about.html")
      expect(page_path).to exist
    end

    it "writes homepage separately" do
      create(:page, site:, slug: "home")

      perform

      page_path = deployment_target.source_path.join("content", "pages", "home.html")
      expect(page_path).to exist
    end

    it "writes project files" do
      project = create(:project, site:)

      perform

      project_path = deployment_target.source_path.join("content", "projects", "#{project.slug}.html")
      expect(project_path).to exist
    end

    it "writes data files" do
      perform

      expect(deployment_target.source_path.join("data", "books.json")).to exist
      expect(deployment_target.source_path.join("data", "projects.json")).to exist
      expect(deployment_target.source_path.join("data", "site.json")).to exist
    end

    it "creates themes symlink" do
      perform

      themes_link = deployment_target.source_path.join("themes")
      expect(themes_link).to be_symlink
      expect(themes_link.readlink).to eq(Rails.root.join("vendor/themes"))
    end

    it "executes hugo build command" do
      perform

      expect(Open3).to have_received(:capture3).with(
        { "HOME" => Dir.home },
        "hugo",
        "--source", deployment_target.source_path.to_s,
        "--destination", deployment_target.deploy_output_path.to_s,
        "--minify",
        timeout: described_class::HUGO_TIMEOUT
      )
    end

    it "runs precompress after hugo build" do
      perform

      expect(StaticSite::PrecompressJob).to have_received(:perform_now)
        .with(deployment_target.deploy_output_path.to_s)
    end

    it "deploys via rclone" do
      perform

      expect(Rclone::Deployer).to have_received(:deploy).with(deployment_target)
    end

    it "cleans up build path before writing" do
      stale_file = deployment_target.source_path.join("leftover.txt")
      FileUtils.mkdir_p(deployment_target.source_path)
      File.write(stale_file, "stale")

      perform

      expect(stale_file).not_to exist
    end

    context "when hugo build fails" do
      before do
        allow(Open3).to receive(:capture3)
          .and_return(["", "Error: template not found", hugo_failure_status])
      end

      it "raises HugoBuildError" do
        expect { perform }.to raise_error(
          Hugo::BuildJob::HugoBuildError,
          /Hugo build failed/
        )
      end

      it "releases the deploy lock on failure" do
        begin
          perform
        rescue Hugo::BuildJob::HugoBuildError
          # expected
        end

        expect(deployment_target.reload.deploying?).to be false
      end
    end
  end

  describe "deploy locking" do
    it "acquires the lock before building" do
      allow(deployment_target).to receive(:acquire_deploy_lock!).and_call_original

      perform

      expect(deployment_target).to have_received(:acquire_deploy_lock!)
    end

    it "releases deploy lock in ensure block" do
      perform

      expect(deployment_target.reload.deploying?).to be false
    end

    it "releases deploy lock even on failure" do
      allow(Open3).to receive(:capture3)
        .and_return(["", "Error", hugo_failure_status])

      expect {
        perform
      }.to raise_error(Hugo::BuildJob::HugoBuildError)

      expect(deployment_target.reload.deploying?).to be false
    end

    it "retries lock acquisition" do
      call_count = 0
      allow(deployment_target).to receive(:acquire_deploy_lock!) do
        call_count += 1
        call_count >= 3
      end

      job = described_class.new
      allow(job).to receive(:sleep)

      job.perform(deployment_target)

      expect(deployment_target).to have_received(:acquire_deploy_lock!).exactly(3).times
      expect(job).to have_received(:sleep).with(described_class::LOCK_RETRY_WAIT).twice
    end

    it "raises DeployLockError after exhausting retries" do
      allow(deployment_target).to receive(:acquire_deploy_lock!).and_return(false)

      job = described_class.new
      allow(job).to receive(:sleep)

      expect {
        job.perform(deployment_target)
      }.to raise_error(Hugo::BuildJob::DeployLockError, /Could not acquire deploy lock/)

      expect(deployment_target).to have_received(:acquire_deploy_lock!)
        .exactly(described_class::LOCK_RETRY_LIMIT).times
    end
  end

  describe "preview mode" do
    it "does not acquire the deploy lock" do
      allow(deployment_target).to receive(:acquire_deploy_lock!)

      perform(preview: true)

      expect(deployment_target).not_to have_received(:acquire_deploy_lock!)
    end

    it "does not release the deploy lock" do
      allow(deployment_target).to receive(:release_deploy_lock!)

      perform(preview: true)

      expect(deployment_target).not_to have_received(:release_deploy_lock!)
    end

    it "skips precompress" do
      perform(preview: true)

      expect(StaticSite::PrecompressJob).not_to have_received(:perform_now)
    end

    it "skips deploy" do
      perform(preview: true)

      expect(Rclone::Deployer).not_to have_received(:deploy)
    end

    it "uses preview output path for hugo build" do
      perform(preview: true)

      expect(Open3).to have_received(:capture3).with(
        { "HOME" => Dir.home },
        "hugo",
        "--source", deployment_target.source_path.to_s,
        "--destination", deployment_target.preview_output_path.to_s,
        "--minify",
        timeout: described_class::HUGO_TIMEOUT
      )
    end

    it "still writes source files" do
      perform(preview: true)

      expect(deployment_target.source_path.join("config.json")).to exist
    end
  end
end
