describe StaticSite::RssFeedRenderer do
  subject(:feed) { described_class.new(site:, routes:).render }

  let(:site) { create(:site, title: "My Site", language_code: "en") }
  let(:routes) do
    StaticSite::Routes.new(site:, site_root: "/", canonical_url: "https://example.com/")
  end

  it "describes the channel with absolute urls" do
    expect(feed).to include("<title>My Site</title>")
    expect(feed).to include("<link>https://example.com/</link>")
    expect(feed).to include('href="https://example.com/feed.xml"')
    expect(feed).to include("<language>en</language>")
  end

  it "links posts absolutely, never relative to the site root" do
    create(:post, site:, title: "Hello", slug: "/hello", publish_at: 1.day.ago)

    expect(feed).to include("<link>https://example.com/hello/</link>")
    expect(feed).to include('isPermaLink="true">https://example.com/hello/')
  end

  it "links a post without a slug by its public id" do
    post = create(:post, site:, slug: nil, publish_at: 1.day.ago)

    expect(feed).to include("https://example.com/posts/#{post.public_id.downcase}/")
  end

  it "omits drafts and future posts" do
    create(:post, site:, title: "Draft post", draft: true)
    create(:post, site:, title: "Future post", publish_at: 1.day.from_now)
    create(:post, site:, title: "Published post", publish_at: 1.day.ago)

    expect(feed).to include("Published post")
    expect(feed).not_to include("Draft post")
    expect(feed).not_to include("Future post")
  end

  it "falls back to a generic title" do
    create(:post, site:, title: nil, publish_at: 1.day.ago)

    expect(feed).to include("<title>Post</title>")
  end

  it "limits the number of items in the feed" do
    create_list(:post, described_class::MAX_ITEMS + 2, site:, publish_at: 1.day.ago)

    expect(feed.scan("<item>").length).to eq(described_class::MAX_ITEMS)
  end
end
