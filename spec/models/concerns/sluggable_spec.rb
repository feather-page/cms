describe Sluggable do
  let(:site) { create(:site) }

  describe "normalisation" do
    it "adds a leading slash" do
      page = create(:page, site:, slug: "about")

      expect(page.slug).to eq("/about")
    end

    it "removes a trailing slash" do
      page = create(:page, site:, slug: "/about/")

      expect(page.slug).to eq("/about")
    end

    it "leaves an already normalised slug alone" do
      page = create(:page, site:, slug: "/about")

      expect(page.slug).to eq("/about")
    end

    it "keeps the homepage slug" do
      page = create(:page, site:, slug: "/")

      expect(page.slug).to eq("/")
    end

    it "turns a blank slug into nil" do
      post = create(:post, site:, slug: "")

      expect(post.slug).to be_nil
    end
  end

  describe "format" do
    it "accepts a nested slug" do
      expect(build(:page, site:, slug: "/blog/my-post")).to be_valid
    end

    it "rejects uppercase and spaces" do
      expect(build(:page, site:, slug: "/My Page")).not_to be_valid
    end
  end

  describe "reserved prefixes" do
    StaticSite::Routes::RESERVED_PREFIXES.each do |prefix|
      it "rejects a page below #{prefix}/" do
        expect(build(:page, site:, slug: "/#{prefix}/something")).not_to be_valid
      end

      it "rejects a post named #{prefix}" do
        expect(build(:post, site:, slug: "/#{prefix}")).not_to be_valid
      end
    end

    StaticSite::Routes::ARTIFACTS.each do |artifact|
      it "rejects a page named #{artifact}" do
        expect(build(:page, site:, slug: "/#{artifact}")).not_to be_valid
      end
    end

    it "allows a project to use a reserved name, because it lives under projects/" do
      expect(build(:project, site:, slug: "/images")).to be_valid
    end

    it "names the reserved slug in a readable error" do
      page = build(:page, site:, slug: "/posts")

      page.validate

      expect(page.errors.full_messages.join).not_to include("translation missing")
      expect(page.errors.full_messages.join).not_to include("Translation missing")
    end
  end

  describe "the site root" do
    it "allows the homepage to own it" do
      expect(build(:page, site:, slug: "/")).to be_valid
    end

    it "rejects a post claiming it" do
      post = build(:post, site:, slug: "/")

      expect(post).not_to be_valid
      expect(post.errors.full_messages.join).not_to include("ranslation missing")
    end

    it "rejects a project claiming it" do
      expect(build(:project, site:, slug: "/")).not_to be_valid
    end
  end
end
