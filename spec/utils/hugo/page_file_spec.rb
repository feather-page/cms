# frozen_string_literal: true

describe Hugo::PageFile do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site: site) }
  let(:page) { create(:page, site: site, title: "About", slug: "/about") }

  subject(:page_file) { described_class.new(page, deployment_target) }

  describe "#relative_path" do
    it "returns the content path for regular pages" do
      expect(page_file.relative_path).to eq("content/pages/#{page.public_id}.html")
    end

    it "returns _index.html for the homepage" do
      homepage = create(:page, site: site, title: "Home", slug: "/")

      file = described_class.new(homepage, deployment_target)
      expect(file.relative_path).to eq("content/_index.html")
    end
  end

  describe "#content" do
    it "includes front matter with layout and title" do
      data = JSON.parse(page_file.content.lines.first)

      expect(data["layout"]).to eq("page")
      expect(data["title"]).to eq("About")
      expect(data["url"]).to eq("/about")
    end

    it "uses home layout for homepage" do
      homepage = create(:page, site: site, title: "Home", slug: "/")

      file = described_class.new(homepage, deployment_target)
      data = JSON.parse(file.content.lines.first)

      expect(data["layout"]).to eq("home")
    end

    it "includes page_type for books pages" do
      books_page = create(:page, :books, site: site, title: "Books", slug: "/books")

      file = described_class.new(books_page, deployment_target)
      data = JSON.parse(file.content.lines.first)

      expect(data["page_type"]).to eq("books")
    end
  end
end
