require "rails_helper"

RSpec.describe StaticSite::Export do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }
  let(:routes) { StaticSite::Routes.for(deployment_target) }
  let(:sink) { StaticSite::RecordingSink.new }

  def export = described_class.new(site:, routes:, sink:).run

  describe "#run" do
    it "exports the home page" do
      export

      expect(sink["index.html"]).to include(ERB::Util.html_escape(site.title))
    end

    context "with pagination" do
      it "paginates posts across multiple pages" do
        create_list(:post, 26, site:, publish_at: 1.day.ago)

        export

        expect(sink.exist?("index.html")).to be true
        expect(sink.exist?("page/2/index.html")).to be true
      end

      it "does not create page/2 when posts fit on one page" do
        create_list(:post, 3, site:, publish_at: 1.day.ago)

        export

        expect(sink.exist?("page/2/index.html")).to be false
      end
    end

    it "exports projects without a double slash in the path" do
      create(:project, site:, slug: "/my-project", title: "My Project")

      export

      expect(sink["projects/my-project/index.html"]).to include("My Project")
    end

    it "exports posts" do
      post = create(:post, site:, title: "Test Post", slug: nil, publish_at: 1.day.ago)

      export

      expect(sink["posts/#{post.public_id.downcase}/index.html"]).to include("Test Post")
    end

    it "exports posts with custom slug" do
      create(:post, site:, title: "Custom Slug Post", slug: "/my-custom-url", publish_at: 1.day.ago)

      export

      expect(sink["my-custom-url/index.html"]).to include("Custom Slug Post")
    end

    it "exports pages" do
      create(:page, site:, title: "About Page", slug: "/about")

      export

      expect(sink["about/index.html"]).to include("About Page")
    end

    it "exports the RSS feed" do
      create(:post, site:, title: "RSS Test Post", publish_at: 1.day.ago)

      export

      expect(sink["feed.xml"]).to include("RSS Test Post")
    end

    it "exports robots.txt" do
      export

      expect(sink["robots.txt"]).to include("User-agent: *")
    end

    it "exports sitemap.xml" do
      export

      expect(sink["sitemap.xml"]).to include("<urlset")
    end

    context "with an internal target" do
      it "links the feed canonically to the public hostname" do
        create(:post, site:, title: "RSS Test Post", publish_at: 1.day.ago)

        export

        expect(sink["feed.xml"]).to include("<link>https://#{deployment_target.public_hostname}/</link>")
      end

      it "does not leak the preview path into robots.txt" do
        export

        expect(sink["robots.txt"]).not_to include("/preview/")
      end
    end

    context "with book reviews" do
      it "includes star ratings in posts" do
        book = create(:book, site:, title: "Clean Code", rating: 4)
        post = create(:post, site:, title: "Book Review", slug: nil, publish_at: 1.day.ago)
        book.update!(post:)

        export

        content = sink["posts/#{post.public_id.downcase}/index.html"]
        expect(content).to include("Clean Code")
        expect(content).to include("★★★★☆")
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

        export

        content = sink["index.html"]
        page_a_pos = content.index("Page A")
        page_c_pos = content.index("Page C")
        page_b_pos = content.index("Page B")

        expect(page_a_pos).to be < page_c_pos, "Page A should appear before Page C"
        expect(page_c_pos).to be < page_b_pos, "Page C should appear before Page B"
      end
    end

    describe "images" do
      it "copies each variant by reference rather than reading the bytes" do
        create(:post, site:, header_image: create(:image, site:), publish_at: 1.day.ago)

        export

        copied = sink.paths.grep(%r{\Aimages/})
        expect(copied).not_to be_empty
        expect(sink[copied.first]).to be_a(StaticSite::RecordingSink::Source)
      end
    end
  end
end
