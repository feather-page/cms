describe StaticSiteHelper do
  let(:helper_instance) { Object.new.extend(described_class) }
  let(:site) { create(:site) }
  let(:image) { create(:image, :with_file, site:) }
  let(:post) { create(:post, site:, publish_at: 1.day.ago) }

  describe "#static_site_post_url" do
    context "without base_url (static site export)" do
      it "returns URL with slug when post has slug" do
        post.update!(slug: "/my-custom-slug")

        expect(helper_instance.static_site_post_url(post)).to eq("/my-custom-slug/")
      end

      it "returns URL with public_id when post has no slug" do
        post.update!(slug: nil)

        expect(helper_instance.static_site_post_url(post)).to eq("/posts/#{post.public_id.downcase}/")
      end
    end

    context "with base_url (preview mode)" do
      before { helper_instance.instance_variable_set(:@base_url, "/preview/ABC123/") }

      it "prepends base_url to slug URL" do
        post.update!(slug: "/my-custom-slug")

        expect(helper_instance.static_site_post_url(post)).to eq("/preview/ABC123/my-custom-slug/")
      end

      it "prepends base_url to public_id URL" do
        post.update!(slug: nil)

        expect(helper_instance.static_site_post_url(post)).to eq("/preview/ABC123/posts/#{post.public_id.downcase}/")
      end
    end
  end

  describe "#static_site_image_url" do
    context "without base_url (static site export)" do
      it "returns absolute image path" do
        result = helper_instance.static_site_image_url(image, :desktop_x1)

        expect(result).to eq("/images/#{image.public_id}/desktop_x1.webp")
      end
    end

    context "with base_url (preview mode)" do
      before { helper_instance.instance_variable_set(:@base_url, "/preview/ABC123/") }

      it "prepends base_url to image path" do
        result = helper_instance.static_site_image_url(image, :desktop_x1)

        expect(result).to eq("/preview/ABC123/images/#{image.public_id}/desktop_x1.webp")
      end
    end

    it "returns nil when image has no file attached" do
      image_without_file = build(:image, site:, file: nil)

      expect(helper_instance.static_site_image_url(image_without_file)).to be_nil
    end
  end

  describe "#static_site_header_image_url" do
    context "without base_url (static site export)" do
      it "returns absolute header image path" do
        expect(helper_instance.static_site_header_image_url(image)).to eq("/images/#{image.public_id}/desktop_x1.webp")
      end
    end

    context "with base_url (preview mode)" do
      before { helper_instance.instance_variable_set(:@base_url, "/preview/ABC123/") }

      it "prepends base_url to header image path" do
        result = helper_instance.static_site_header_image_url(image)

        expect(result).to eq("/preview/ABC123/images/#{image.public_id}/desktop_x1.webp")
      end
    end
  end

  describe "#static_site_header_image_srcset" do
    context "without base_url (static site export)" do
      it "returns srcset with absolute paths" do
        srcset = helper_instance.static_site_header_image_srcset(image)

        expect(srcset).to include("/images/#{image.public_id}/mobile_x1.webp")
        expect(srcset).not_to include("/preview/")
      end
    end

    context "with base_url (preview mode)" do
      before { helper_instance.instance_variable_set(:@base_url, "/preview/ABC123/") }

      it "prepends base_url to all srcset paths" do
        srcset = helper_instance.static_site_header_image_srcset(image)

        expect(srcset).to include("/preview/ABC123/images/#{image.public_id}/mobile_x1.webp")
      end
    end
  end

  describe "#static_site_content_html" do
    context "without base_url (static site export)" do
      it "preserves image paths" do
        html = '<img src="/images/abc123/desktop_x1.webp">'

        expect(helper_instance.static_site_content_html(html)).to eq('<img src="/images/abc123/desktop_x1.webp">')
      end
    end

    context "with base_url (preview mode)" do
      before { helper_instance.instance_variable_set(:@base_url, "/preview/ABC123/") }

      it "prepends base_url to image paths in content" do
        html = '<img src="/images/abc123/desktop_x1.webp">'
        result = helper_instance.static_site_content_html(html)

        expect(result).to eq('<img src="/preview/ABC123/images/abc123/desktop_x1.webp">')
      end
    end
  end
end
