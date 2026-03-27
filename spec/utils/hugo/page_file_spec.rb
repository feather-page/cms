require "rails_helper"

RSpec.describe Hugo::PageFile do
  let(:build_path) { Pathname.new(Dir.mktmpdir) }
  let(:site) { create(:site) }
  let(:page) { create(:page, site: site, title: "About", slug: "about", emoji: "📄") }

  subject(:file) { described_class.new(build_path: build_path, page: page) }

  after { FileUtils.rm_rf(build_path) }

  describe "#relative_path" do
    it "returns the content path based on slug" do
      expect(file.relative_path).to eq("content/pages/about.html")
    end
  end

  describe "#content" do
    it "contains JSON front matter followed by hugo_html" do
      content = file.content
      parts = content.split("\n\n", 2)
      expect { JSON.parse(parts.first) }.not_to raise_error
    end

    it "includes the page title in front matter" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["title"]).to eq("About")
    end

    it "includes the url based on slug" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["url"]).to eq("/about/")
    end

    it "includes emoji" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["emoji"]).to eq("📄")
    end

    it "does not include page_type for default pages" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter).not_to have_key("page_type")
    end

    it "does not include layout for non-homepage" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter).not_to have_key("layout")
    end

    it "does not include menu when not in navigation" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter).not_to have_key("menu")
    end

    context "when page is the homepage" do
      let(:page) { create(:page, site: site, title: "Home", slug: "/", emoji: "🏠") }

      it "includes layout: home" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["layout"]).to eq("home")
      end
    end

    context "when page has a special page_type" do
      let(:page) { create(:page, :books, site: site, title: "Books", slug: "books", emoji: "📚") }

      it "includes page_type in front matter" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["page_type"]).to eq("books")
      end
    end

    context "when page is in navigation" do
      let(:navigation) { create(:navigation, site: site) }
      let(:page) { create(:page, site: site, title: "About", slug: "about", emoji: "📄") }

      before do
        create(:navigation_item, navigation: navigation, page: page)
        page.reload
      end

      it "includes menu with weight" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["menu"]["main"]["weight"]).to be_a(Integer)
      end
    end

    context "with a header image" do
      let(:page) do
        p = create(:page, site: site, title: "With Image", slug: "with-image")
        p.update!(header_image: create(:image, site: site, imageable: p))
        p.reload
      end

      it "includes header_image data with url" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["header_image"]["url"]).to include("/images/")
      end
    end

    it "includes hugo_html as the body" do
      allow(page).to receive(:hugo_html).and_return("<p>About me</p>")
      parts = file.content.split("\n\n", 2)
      expect(parts.last).to eq("<p>About me</p>")
    end
  end

  describe "#write" do
    it "writes the file to the correct path" do
      file.write
      written_path = build_path.join("content/pages/about.html")
      expect(written_path).to exist
    end
  end
end
