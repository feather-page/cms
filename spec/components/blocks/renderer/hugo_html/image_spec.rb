# frozen_string_literal: true

describe Blocks::Renderer::HugoHtml::Image do
  let(:image) { create(:image) }
  let(:block) do
    Blocks::Image.new(id: "A70r8-SIog", image_id: image.public_id, caption: caption)
  end

  before do
    allow(image).to receive_messages(width: 10, height: 10)
    allow(Image).to receive(:find).with(image.public_id).and_return(image)
  end

  describe "#variant_url" do
    let(:renderer) { described_class.new(block) }
    let(:caption) { "" }

    it "returns the Hugo image path for mobile_x1_webp variant" do
      expect(renderer.variant_url(:mobile_x1_webp)).to eq("/images/#{image.public_id}/mobile_x1.webp")
    end

    it "returns the Hugo image path for desktop_x2_jpg variant" do
      expect(renderer.variant_url(:desktop_x2_jpg)).to eq("/images/#{image.public_id}/desktop_x2.jpg")
    end
  end

  describe "#to_html" do
    let(:image_html) { described_class.new(block).to_html }

    context "with a caption" do
      let(:caption) { "A beautiful image" }

      it "includes the caption" do
        expect(image_html).to include("<figcaption>#{caption}</figcaption>")
      end

      it "uses Hugo-compatible image paths" do
        expect(image_html).to include("/images/#{image.public_id}/")
      end
    end

    context "without a caption" do
      let(:caption) { "" }

      it "does not include a figcaption" do
        expect(image_html).not_to include("<figcaption>")
      end
    end
  end
end
