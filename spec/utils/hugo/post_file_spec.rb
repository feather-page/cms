require "rails_helper"

RSpec.describe Hugo::PostFile do
  let(:build_path) { Pathname.new(Dir.mktmpdir) }
  let(:site) { create(:site) }
  let(:post) { create(:post, site: site, title: "Hello World", emoji: "👋", draft: false) }

  subject(:file) { described_class.new(build_path: build_path, post: post) }

  after { FileUtils.rm_rf(build_path) }

  describe "#relative_path" do
    it "returns the content path based on slug" do
      expect(file.relative_path).to eq("content/posts/#{post.slug}.html")
    end
  end

  describe "#content" do
    it "contains JSON front matter followed by hugo_html" do
      content = file.content
      parts = content.split("\n\n", 2)
      expect { JSON.parse(parts.first) }.not_to raise_error
    end

    it "includes the post title in front matter" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["title"]).to eq("Hello World")
    end

    it "includes the created_at date in ISO 8601 format" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["date"]).to eq(post.created_at.iso8601)
    end

    it "includes the url based on slug" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["url"]).to eq("/#{post.slug}/")
    end

    it "includes draft status" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["draft"]).to be false
    end

    it "includes emoji" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["emoji"]).to eq("👋")
    end

    it "includes an empty tag list when untagged" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["tags"]).to eq([])
    end

    context "with tags" do
      let(:post) { create(:post, :tagged, site: site, title: "Tagged Post") }

      it "includes tags as an array" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["tags"]).to eq(%w[ruby rails web])
      end
    end

    context "with publish_at" do
      let(:publish_time) { 1.day.from_now }
      let(:post) { create(:post, site: site, title: "Scheduled", publish_at: publish_time) }

      it "includes publishDate" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["publishDate"]).to eq(publish_time.iso8601)
      end
    end

    context "with a draft post" do
      let(:post) { create(:post, site: site, title: "Draft", draft: true) }

      it "sets draft to true" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["draft"]).to be true
      end
    end

    context "with a header image" do
      let(:image) { create(:image, site: site, imageable: post) }
      let(:post) do
        p = create(:post, site: site, title: "With Image")
        p.update!(header_image: create(:image, site: site, imageable: p))
        p.reload
      end

      it "includes header_image data with url and srcset" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["header_image"]["url"]).to include("/images/")
        expect(front_matter["header_image"]["srcset"]).to include("w")
      end
    end

    context "with an associated book" do
      let(:book) { create(:book, site: site, title: "Test Book", author: "Author", emoji: "📚", rating: 5) }
      let(:post) { create(:post, site: site, title: "Book Review") }

      before { book.update!(post: post) }

      it "includes book metadata" do
        post.reload
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["book"]["title"]).to eq("Test Book")
        expect(front_matter["book"]["author"]).to eq("Author")
        expect(front_matter["book"]["emoji"]).to eq("📚")
        expect(front_matter["book"]["rating"]).to eq(5)
        expect(front_matter["book"]["public_id"]).to eq(book.public_id)
      end
    end

    it "includes hugo_html as the body" do
      allow(post).to receive(:hugo_html).and_return("<p>Hello</p>")
      parts = file.content.split("\n\n", 2)
      expect(parts.last).to eq("<p>Hello</p>")
    end
  end

  describe "#write" do
    it "writes the file to the correct path" do
      file.write
      written_path = build_path.join("content/posts/#{post.slug}.html")
      expect(written_path).to exist
    end
  end
end
