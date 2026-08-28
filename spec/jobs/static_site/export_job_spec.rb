require "rails_helper"

RSpec.describe StaticSite::ExportJob do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }
  let(:deployer) { class_spy(Rclone::Deployer) }
  let(:noticer) { instance_spy(Noticer) }
  let(:noticer_class) { class_spy(Noticer, new: noticer) }

  before do
    allow(StaticSite::PrecompressJob).to receive(:perform_now)
  end

  after do
    FileUtils.rm_rf(deployment_target.build_path)
  end

  def perform
    described_class.perform_now(deployment_target, deployer:, noticer: noticer_class)
  end

  describe "#perform" do
    it "renders the site into the deployed directory" do
      create(:post, site:, title: "End To End", slug: "/e2e", publish_at: 1.day.ago)

      perform

      index = File.join(deployment_target.source_dir, "index.html")
      post = File.join(deployment_target.source_dir, "e2e", "index.html")
      expect(File.read(index)).to include(ERB::Util.html_escape(site.title))
      expect(File.read(post)).to include("End To End")
    end

    it "precompresses what the export built, before publishing it" do
      built_dir = nil
      allow(StaticSite::PrecompressJob).to receive(:perform_now) { |dir| built_dir = dir }

      perform

      expect(built_dir).to be_present
      expect(built_dir).not_to eq(deployment_target.source_dir)
      expect(File.dirname(built_dir)).to eq(deployment_target.build_path)
    end

    it "deploys via rclone" do
      perform

      expect(deployer).to have_received(:deploy).with(deployment_target)
    end

    it "sends a success notification" do
      perform

      expect(noticer_class).to have_received(:new).with(site)
      expect(noticer).to have_received(:notice).with(
        "Site built. <a href='https://#{deployment_target.public_hostname}'>Preview</a>"
      )
    end

    it "leaves no build directory behind" do
      perform

      leftovers = Dir.children(deployment_target.build_path)
      expect(leftovers).to eq(["public"])
    end
  end

  describe "publishing" do
    it "replaces the previously deployed directory" do
      stale = File.join(deployment_target.source_dir, "gone.html")
      FileUtils.mkdir_p(deployment_target.source_dir)
      File.write(stale, "from an earlier run")

      perform

      expect(File.exist?(stale)).to be false
      expect(File.exist?(File.join(deployment_target.source_dir, "index.html"))).to be true
    end

    it "leaves the deployed directory untouched when the export fails" do
      FileUtils.mkdir_p(deployment_target.source_dir)
      File.write(File.join(deployment_target.source_dir, "index.html"), "the live site")
      allow(StaticSite::Export).to receive(:new).and_raise(RuntimeError, "boom")

      expect { perform }.to raise_error(RuntimeError, "boom")

      expect(File.read(File.join(deployment_target.source_dir, "index.html"))).to eq("the live site")
    end

    it "discards the build directory when the export fails" do
      allow(StaticSite::Export).to receive(:new).and_raise(RuntimeError, "boom")

      expect { perform }.to raise_error(RuntimeError, "boom")

      expect(Dir.children(deployment_target.build_path)).to be_empty
    end
  end

  describe "deploy locking" do
    it "releases the lock after a successful export" do
      perform

      expect(deployment_target.reload.deploying?).to be false
    end

    it "retries when lock is already held" do
      deployment_target.update!(deploying: true)

      job = described_class.new
      allow(job).to receive(:retry_job)

      job.perform(deployment_target, deployer:, noticer: noticer_class)

      expect(job).to have_received(:retry_job).with(wait: 5.seconds)
      expect(deployer).not_to have_received(:deploy)
    end

    it "releases the lock when an error occurs during export" do
      deployment_target
      allow(StaticSite::PrecompressJob).to receive(:perform_now).and_raise(RuntimeError, "boom")

      expect { perform }.to raise_error(RuntimeError, "boom")

      expect(deployment_target.reload.deploying?).to be false
    end

    it "does not release the lock when it was not acquired" do
      deployment_target.update!(deploying: true)

      job = described_class.new
      allow(job).to receive(:retry_job)
      allow(deployment_target).to receive(:release_deploy_lock!)

      job.perform(deployment_target, deployer:, noticer: noticer_class)

      expect(deployment_target).not_to have_received(:release_deploy_lock!)
    end

    it "gives up after 60 retries and logs a warning" do
      deployment_target.update!(deploying: true)

      job = described_class.new
      allow(job).to receive(:executions).and_return(60)
      allow(job).to receive(:retry_job)
      allow(Rails.logger).to receive(:warn)

      job.perform(deployment_target, deployer:, noticer: noticer_class)

      expect(job).not_to have_received(:retry_job)
      expect(Rails.logger).to have_received(:warn).with(/stuck/)
      expect(deployer).not_to have_received(:deploy)
    end
  end
end
