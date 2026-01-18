require "rails_helper"

RSpec.describe StaticSite::ExportJob do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }

  before do
    allow(StaticSite::PrecompressJob).to receive(:perform_now)
    allow(Rclone::DeployJob).to receive(:perform_later)
  end

  after do
    FileUtils.rm_rf(deployment_target.build_path)
  end

  describe "#perform" do
    it "creates the output directory" do
      described_class.perform_now(deployment_target)

      expect(Dir.exist?(deployment_target.source_dir)).to be true
    end

    it "exports the home page" do
      described_class.perform_now(deployment_target)

      index_path = File.join(deployment_target.source_dir, "index.html")
      expect(File.exist?(index_path)).to be true
      expect(File.read(index_path)).to include(site.title)
    end

    it "exports posts" do
      post = create(:post, site:, title: "Test Post", slug: nil, publish_at: 1.day.ago)

      described_class.perform_now(deployment_target)

      post_path = File.join(deployment_target.source_dir, "posts", post.public_id.downcase, "index.html")
      expect(File.exist?(post_path)).to be true
      expect(File.read(post_path)).to include("Test Post")
    end

    it "exports posts with custom slug" do
      create(:post, site:, title: "Custom Slug Post", slug: "/my-custom-url", publish_at: 1.day.ago)

      described_class.perform_now(deployment_target)

      post_path = File.join(deployment_target.source_dir, "my-custom-url", "index.html")
      expect(File.exist?(post_path)).to be true
      expect(File.read(post_path)).to include("Custom Slug Post")
    end

    it "exports pages" do
      create(:page, site:, title: "About Page", slug: "/about")

      described_class.perform_now(deployment_target)

      page_path = File.join(deployment_target.source_dir, "about", "index.html")
      expect(File.exist?(page_path)).to be true
      expect(File.read(page_path)).to include("About Page")
    end

    it "exports the RSS feed" do
      create(:post, site:, title: "RSS Test Post", publish_at: 1.day.ago)

      described_class.perform_now(deployment_target)

      feed_path = File.join(deployment_target.source_dir, "feed.xml")
      expect(File.exist?(feed_path)).to be true
      expect(File.read(feed_path)).to include("RSS Test Post")
    end

    it "exports robots.txt" do
      described_class.perform_now(deployment_target)

      robots_path = File.join(deployment_target.source_dir, "robots.txt")
      expect(File.exist?(robots_path)).to be true
      expect(File.read(robots_path)).to include("User-agent: *")
    end

    it "calls precompress job" do
      described_class.perform_now(deployment_target)

      expect(StaticSite::PrecompressJob).to have_received(:perform_now).with(deployment_target.source_dir)
    end

    it "triggers deployment" do
      described_class.perform_now(deployment_target)

      expect(Rclone::DeployJob).to have_received(:perform_later).with(deployment_target)
    end

    context "with book reviews" do
      it "includes star ratings in posts" do
        book = create(:book, site:, title: "Clean Code", rating: 4)
        post = create(:post, site:, title: "Book Review", slug: nil, publish_at: 1.day.ago)
        book.update!(post:)

        described_class.perform_now(deployment_target)

        post_path = File.join(deployment_target.source_dir, "posts", post.public_id.downcase, "index.html")
        content = File.read(post_path)
        expect(content).to include("Clean Code")
        expect(content).to include("\u2605\u2605\u2605\u2605\u2606")
      end
    end
  end
end
