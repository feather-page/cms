describe StaticSite::OutputPaths do
  let(:test_class) { Class.new { include StaticSite::OutputPaths } }
  let(:helper) { test_class.new }

  describe "#post_output_path" do
    let(:post) { build(:post, slug: "/my-awesome-post", public_id: "abc123XYZ") }

    context "when post has a slug" do
      it "returns the slug-based path with index.html" do
        expect(helper.post_output_path(post)).to eq("my-awesome-post/index.html")
      end

      it "removes leading slash from slug" do
        post.slug = "/blog/my-post"
        expect(helper.post_output_path(post)).to eq("blog/my-post/index.html")
      end
    end

    context "when post has no slug" do
      let(:post) { build(:post, slug: nil, public_id: "ABC123xyz") }

      it "returns public_id-based path with lowercase id" do
        expect(helper.post_output_path(post)).to eq("posts/abc123xyz/index.html")
      end
    end

    context "when post has blank slug" do
      let(:post) { build(:post, slug: "", public_id: "DEF456uvw") }

      it "returns public_id-based path" do
        expect(helper.post_output_path(post)).to eq("posts/def456uvw/index.html")
      end
    end
  end

  describe "#page_output_path" do
    let(:page) { build(:page, slug: "/about") }

    it "returns the slug-based path with index.html" do
      expect(helper.page_output_path(page)).to eq("about/index.html")
    end

    it "removes leading slash from slug" do
      page.slug = "/contact/info"
      expect(helper.page_output_path(page)).to eq("contact/info/index.html")
    end

    context "when slug is root" do
      let(:page) { build(:page, slug: "/") }

      it "returns index.html for root page" do
        expect(helper.page_output_path(page)).to eq("/index.html")
      end
    end
  end

  describe "#image_output_path" do
    let(:image) { build(:image, public_id: "img123") }

    it "returns correct path for mobile_x1_webp variant" do
      expect(helper.image_output_path(image, :mobile_x1_webp)).to eq("images/img123/mobile_x1.webp")
    end

    it "returns correct path for desktop_x2_jpg variant" do
      expect(helper.image_output_path(image, :desktop_x2_jpg)).to eq("images/img123/desktop_x2.jpg")
    end

    it "returns correct path for mobile_x2_webp variant" do
      expect(helper.image_output_path(image, :mobile_x2_webp)).to eq("images/img123/mobile_x2.webp")
    end

    it "handles variant keys as strings" do
      expect(helper.image_output_path(image, "desktop_x1_png")).to eq("images/img123/desktop_x1.png")
    end
  end
end
