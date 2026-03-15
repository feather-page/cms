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
    it "creates the output directory" do
      perform

      expect(Dir.exist?(deployment_target.source_dir)).to be true
    end

    it "exports the home page" do
      perform

      index_path = File.join(deployment_target.source_dir, "index.html")
      expect(File.exist?(index_path)).to be true
      expect(File.read(index_path)).to include(ERB::Util.html_escape(site.title))
    end

    context "with pagination" do
      it "paginates posts across multiple pages" do
        create_list(:post, 26, site:, publish_at: 1.day.ago)

        perform

        page1_path = File.join(deployment_target.source_dir, "index.html")
        page2_path = File.join(deployment_target.source_dir, "page", "2", "index.html")
        expect(File.exist?(page1_path)).to be true
        expect(File.exist?(page2_path)).to be true
      end

      it "does not create page/2 when posts fit on one page" do
        create_list(:post, 3, site:, publish_at: 1.day.ago)

        perform

        page2_path = File.join(deployment_target.source_dir, "page", "2", "index.html")
        expect(File.exist?(page2_path)).to be false
      end
    end

    it "exports posts" do
      post = create(:post, site:, title: "Test Post", slug: nil, publish_at: 1.day.ago)

      perform

      post_path = File.join(deployment_target.source_dir, "posts", post.public_id.downcase, "index.html")
      expect(File.exist?(post_path)).to be true
      expect(File.read(post_path)).to include("Test Post")
    end

    it "exports posts with custom slug" do
      create(:post, site:, title: "Custom Slug Post", slug: "/my-custom-url", publish_at: 1.day.ago)

      perform

      post_path = File.join(deployment_target.source_dir, "my-custom-url", "index.html")
      expect(File.exist?(post_path)).to be true
      expect(File.read(post_path)).to include("Custom Slug Post")
    end

    it "exports pages" do
      create(:page, site:, title: "About Page", slug: "/about")

      perform

      page_path = File.join(deployment_target.source_dir, "about", "index.html")
      expect(File.exist?(page_path)).to be true
      expect(File.read(page_path)).to include("About Page")
    end

    it "exports the RSS feed" do
      create(:post, site:, title: "RSS Test Post", publish_at: 1.day.ago)

      perform

      feed_path = File.join(deployment_target.source_dir, "feed.xml")
      expect(File.exist?(feed_path)).to be true
      expect(File.read(feed_path)).to include("RSS Test Post")
    end

    it "exports robots.txt" do
      perform

      robots_path = File.join(deployment_target.source_dir, "robots.txt")
      expect(File.exist?(robots_path)).to be true
      expect(File.read(robots_path)).to include("User-agent: *")
    end

    it "calls precompress job" do
      perform

      expect(StaticSite::PrecompressJob).to have_received(:perform_now).with(deployment_target.source_dir)
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

    context "with book reviews" do
      it "includes star ratings in posts" do
        book = create(:book, site:, title: "Clean Code", rating: 4)
        post = create(:post, site:, title: "Book Review", slug: nil, publish_at: 1.day.ago)
        book.update!(post:)

        perform

        post_path = File.join(deployment_target.source_dir, "posts", post.public_id.downcase, "index.html")
        content = File.read(post_path)
        expect(content).to include("Clean Code")
        expect(content).to include("\u2605\u2605\u2605\u2605\u2606")
      end
    end

    context "with navigation items" do
      it "exports navigation links in the correct order" do
        navigation = site.main_navigation

        page_c = create(:page, site:, title: "Page C", slug: "/page-c")
        page_a = create(:page, site:, title: "Page A", slug: "/page-a")
        page_b = create(:page, site:, title: "Page B", slug: "/page-b")

        navigation.add(page_c)
        nav_item_a = navigation.add(page_a)
        navigation.add(page_b)

        nav_item_a.move_up

        perform

        index_path = File.join(deployment_target.source_dir, "index.html")
        content = File.read(index_path)

        page_a_pos = content.index("Page A")
        page_c_pos = content.index("Page C")
        page_b_pos = content.index("Page B")

        expect(page_a_pos).to be < page_c_pos, "Page A should appear before Page C"
        expect(page_c_pos).to be < page_b_pos, "Page C should appear before Page B"
      end
    end
  end

  describe "deploy locking" do
    it "acquires the lock before exporting" do
      perform

      expect(deployment_target.reload.deploying?).to be false # released in ensure
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
      deployment_target # ensure created before stubbing
      allow(StaticSite::PrecompressJob).to receive(:perform_now).and_raise(RuntimeError, "boom")

      expect {
        perform
      }.to raise_error(RuntimeError, "boom")

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
