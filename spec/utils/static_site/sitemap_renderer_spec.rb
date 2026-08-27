describe StaticSite::SitemapRenderer do
  subject(:sitemap) { described_class.new(site:, routes:).render }

  let(:site) { create(:site, title: "My Site") }
  let(:routes) do
    StaticSite::Routes.new(site:, site_root: "/", canonical_url: "https://example.com/")
  end

  it "lists the home page by its canonical url" do
    expect(sitemap).to include("<loc>https://example.com/</loc>")
  end

  it "lists posts, pages and projects" do
    create(:post, site:, title: "Post", slug: "/p", publish_at: 1.day.ago)
    create(:page, site:, title: "About", slug: "/about")
    create(:project, site:, slug: "/proj")

    expect(sitemap).to include("<loc>https://example.com/p/</loc>")
    expect(sitemap).to include("<loc>https://example.com/about/</loc>")
    expect(sitemap).to include("<loc>https://example.com/projects/proj/</loc>")
  end

  it "omits drafts and future posts" do
    create(:post, site:, title: "Draft", draft: true)
    create(:post, site:, title: "Future", publish_at: 1.day.from_now)

    expect(sitemap).not_to include("draft")
    expect(sitemap).not_to include("future")
  end

  it "does not duplicate the home page slug" do
    create(:page, site:, title: "Home", slug: "/")

    expect(sitemap.scan("<loc>").count).to eq(1)
  end

  it "adds a lastmod timestamp to each entry" do
    expect(sitemap).to match(/<lastmod>\d{4}-\d{2}-\d{2}T/)
  end
end
