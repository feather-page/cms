describe Blocks::Renderer::StaticSiteHtml::Image do
  let(:image) { create(:image) }
  let(:block) do
    Blocks::Image.new(id: "A70r8-SIog", image_id: image.public_id, caption:)
  end

  before do
    allow(image).to receive_messages(width: 10, height: 10)
    allow(Image).to receive(:find).with(image.public_id).and_return(image)
  end

  describe "#variant_url" do
    let(:renderer) { described_class.new(block) }
    let(:caption) { "" }

    it "returns the static site image path for mobile_x1_webp variant" do
      expect(renderer.variant_url(:mobile_x1_webp)).to eq("/images/#{image.public_id}/mobile_x1.webp")
    end

    it "returns the static site image path for desktop_x2_jpg variant" do
      expect(renderer.variant_url(:desktop_x2_jpg)).to eq("/images/#{image.public_id}/desktop_x2.jpg")
    end

    it "returns the static site image path for mobile_x2_webp variant" do
      expect(renderer.variant_url(:mobile_x2_webp)).to eq("/images/#{image.public_id}/mobile_x2.webp")
    end
  end

  describe "#to_html" do
    let(:image_html) { described_class.new(block).to_html }

    context "with a caption" do
      let(:caption) { "A beautiful image" }

      it "returns the html with alt-attribute and caption" do
        expect(image_html).to include("<figcaption>#{caption}</figcaption>")
        expect(image_html).to include('alt="A beautiful image"')
      end

      it "uses static site paths for images" do
        expect(image_html).to include("/images/#{image.public_id}/")
      end
    end

    context "without a caption" do
      let(:caption) { "" }

      it "returns the html with empty alt-attribute and no caption" do
        expect(image_html).to include('alt=""')
        expect(image_html).not_to include("<figcaption>")
      end
    end
  end
end
