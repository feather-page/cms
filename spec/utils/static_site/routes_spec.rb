describe StaticSite::Routes do
  subject(:routes) { described_class.new(site:, site_root: "/", canonical_url: "https://example.com/") }

  let(:site) { create(:site) }

  describe "#home_url and #home_path" do
    it "addresses the first page as the site root" do
      expect(routes.home_url).to eq("/")
      expect(routes.home_path).to eq("index.html")
    end

    it "addresses later pages under page/" do
      expect(routes.home_url(page: 3)).to eq("/page/3/")
      expect(routes.home_path(page: 3)).to eq("page/3/index.html")
    end
  end

  describe "#post_url and #post_path" do
    it "uses the slug when the post has one" do
      post = build(:post, site:, slug: "/hello-world")

      expect(routes.post_url(post)).to eq("/hello-world/")
      expect(routes.post_path(post)).to eq("hello-world/index.html")
    end

    it "falls back to the lowercased public id without a slug" do
      post = build(:post, site:, slug: nil, public_id: "ABC123xyz789")

      expect(routes.post_url(post)).to eq("/posts/abc123xyz789/")
      expect(routes.post_path(post)).to eq("posts/abc123xyz789/index.html")
    end
  end

  describe "#page_url and #page_path" do
    it "uses the slug" do
      page = build(:page, site:, slug: "/about")

      expect(routes.page_url(page)).to eq("/about/")
      expect(routes.page_path(page)).to eq("about/index.html")
    end

    it "addresses the homepage as the site root" do
      page = build(:page, site:, slug: "/")

      expect(routes.page_url(page)).to eq("/")
      expect(routes.page_path(page)).to eq("index.html")
    end
  end

  describe "#project_url and #project_path" do
    it "nests projects under projects/" do
      project = build(:project, site:, slug: "/my-project")

      expect(routes.project_url(project)).to eq("/projects/my-project/")
      expect(routes.project_path(project)).to eq("projects/my-project/index.html")
    end

    it "produces the same address for a slug stored without a leading slash" do
      with_slash = build(:project, site:, slug: "/my-project")
      without_slash = build(:project, site:, slug: "my-project")

      expect(routes.project_path(without_slash)).to eq(routes.project_path(with_slash))
      expect(routes.project_url(without_slash)).to eq(routes.project_url(with_slash))
    end
  end

  describe "#image_url and #image_path" do
    it "addresses a variant by its filename" do
      image = build(:image, site:, public_id: "img123456789")

      expect(routes.image_url(image, :mobile_x1_webp)).to eq("/images/img123456789/mobile_x1.webp")
      expect(routes.image_path(image, :desktop_x1_jpg)).to eq("images/img123456789/desktop_x1.jpg")
    end

    it "rejects an unknown variant" do
      image = build(:image, site:)

      expect { routes.image_url(image, :desktop_x1_png) }.to raise_error(ArgumentError)
    end
  end

  describe "#artifact_url and #artifact_path" do
    it "addresses known artifacts" do
      expect(routes.artifact_url("feed.xml")).to eq("/feed.xml")
      expect(routes.artifact_path("sitemap.xml")).to eq("sitemap.xml")
      expect(routes.artifact_url("robots.txt")).to eq("/robots.txt")
    end

    it "rejects an unknown artifact" do
      expect { routes.artifact_url("humans.txt") }.to raise_error(ArgumentError)
    end
  end

  describe "#canonical" do
    it "returns the same addresses against the canonical url" do
      post = build(:post, site:, slug: "/hello")

      expect(routes.canonical.post_url(post)).to eq("https://example.com/hello/")
      expect(routes.canonical.artifact_url("feed.xml")).to eq("https://example.com/feed.xml")
    end

    it "returns itself when site root and canonical url already match" do
      plain = described_class.new(site:)

      expect(plain.canonical).to be(plain)
    end
  end

  describe ".for" do
    let(:deployment_target) do
      build(:deployment_target, site:, public_hostname: "example.com", public_id: "dt0123456789")
    end

    it "addresses a deployed site from its root" do
      deployed = described_class.for(deployment_target)

      expect(deployed.site_root).to eq("/")
      expect(deployed.canonical_url).to eq("https://example.com/")
    end

    it "addresses a preview under the deployment target's public id" do
      preview = described_class.for(deployment_target, as: :preview)

      expect(preview.site_root).to eq("/preview/dt0123456789/")
      expect(preview.canonical_url).to eq("https://example.com/")
    end

    it "uses the public hostname for internal targets too" do
      internal = build(:deployment_target, :staging, site:, public_hostname: "abc.stage.test")

      expect(described_class.for(internal).canonical_url).to eq("https://abc.stage.test/")
    end
  end

  describe "#resolve" do
    it "resolves the site root to the first home page" do
      ["", "/", "index.html", "index"].each do |path|
        expect(routes.resolve(path)).to eq(StaticSite::Route.build(:home, page: 1))
      end
    end

    it "resolves a paginated home page" do
      expect(routes.resolve("page/4")).to eq(StaticSite::Route.build(:home, page: 4))
      expect(routes.resolve("page/4/index.html")).to eq(StaticSite::Route.build(:home, page: 4))
    end

    it "resolves artifacts" do
      expect(routes.resolve("feed.xml")).to eq(StaticSite::Route.build(:artifact, name: "feed.xml"))
    end

    it "resolves an image variant" do
      image = create(:image, site:)

      route = routes.resolve("images/#{image.public_id}/mobile_x2.webp")

      expect(route.kind).to eq(:image)
      expect(route.record).to eq(image)
      expect(route.params[:variant]).to eq(:mobile_x2_webp)
    end

    it "does not resolve an unknown image variant" do
      image = create(:image, site:)

      expect(routes.resolve("images/#{image.public_id}/mobile_x2.png")).to be_nil
    end

    it "resolves a project by slug, stored with or without a leading slash" do
      slashed = create(:project, site:, slug: "/alpha")
      bare = create(:project, site:, slug: "beta")

      expect(routes.resolve("projects/alpha").record).to eq(slashed)
      expect(routes.resolve("projects/beta").record).to eq(bare)
    end

    it "resolves a post by public id" do
      post = create(:post, site:, slug: nil)

      expect(routes.resolve("posts/#{post.public_id.downcase}").record).to eq(post)
    end

    it "resolves a page by slug" do
      page = create(:page, site:, slug: "/about")

      expect(routes.resolve("about").record).to eq(page)
    end

    it "resolves a post by slug" do
      post = create(:post, site:, slug: "/hello")

      expect(routes.resolve("hello").record).to eq(post)
    end

    it "prefers a page over a post when both carry the same slug" do
      page = create(:page, site:, slug: "/clash")
      create(:post, site:, slug: "/clash")

      expect(routes.resolve("clash").record).to eq(page)
    end

    it "does not resolve content of another site" do
      other_post = create(:post, slug: "/foreign")

      expect(routes.resolve("foreign")).to be_nil
      expect(other_post.site).not_to eq(site)
    end

    it "resolves a post and a page alike when addressed with .html" do
      page = create(:page, site:, slug: "/about")
      post = create(:post, site:, slug: "/hello")

      expect(routes.resolve("about.html").record).to eq(page)
      expect(routes.resolve("hello.html").record).to eq(post)
    end

    it "only strips index.html at a path boundary" do
      create(:page, site:, slug: "/about")

      expect(routes.resolve("aboutindex.html")).to be_nil
      expect(routes.resolve("about/index.html").record).to eq(Page.find_by(slug: "/about"))
    end

    it "returns nil for an unknown path" do
      expect(routes.resolve("nope/not/here")).to be_nil
    end

    it "does not resolve a page number below one" do
      expect(routes.resolve("page/0")).to be_nil
    end
  end

  describe "round trip" do
    it "resolves every path it generates back to the same route" do
      post = create(:post, site:, slug: "/hello")
      slugless_post = create(:post, site:, slug: nil)
      page = create(:page, site:, slug: "/about")
      project = create(:project, site:, slug: "/alpha")
      create(:image, site:)

      expectations = {
        routes.home_path => StaticSite::Route.build(:home, page: 1),
        routes.home_path(page: 2) => StaticSite::Route.build(:home, page: 2),
        routes.post_path(post) => StaticSite::Route.build(:post, record: post),
        routes.post_path(slugless_post) => StaticSite::Route.build(:post, record: slugless_post),
        routes.page_path(page) => StaticSite::Route.build(:page, record: page),
        routes.project_path(project) => StaticSite::Route.build(:project, record: project),
        routes.artifact_path("feed.xml") => StaticSite::Route.build(:artifact, name: "feed.xml")
      }

      expectations.each do |path, expected|
        expect(routes.resolve(path)).to eq(expected)
      end
    end

    it "round-trips every image variant" do
      image = create(:image, site:)

      Image::Variants.each_key do |variant|
        route = routes.resolve(routes.image_path(image, variant))

        expect(route.record).to eq(image)
        expect(route.params[:variant]).to eq(variant)
      end
    end

    it "round-trips urls as well as paths" do
      post = create(:post, site:, slug: "/hello")

      expect(routes.resolve(routes.post_url(post)).record).to eq(post)
      expect(routes.resolve(routes.home_url(page: 5))).to eq(StaticSite::Route.build(:home, page: 5))
    end
  end
end
