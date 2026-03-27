require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Image do
  let(:image) { create(:image) }
  let(:block) do
    Blocks::Image.new(id: "img123", image_id: image.public_id, caption: caption)
  end

  before do
    allow(block).to receive(:image).and_return(image)
  end

  describe "#to_html" do
    context "with a caption" do
      let(:caption) { "A beautiful sunset" }

      it "renders a Hugo image shortcode with id and caption" do
        result = described_class.new(block).to_html
        expect(result).to eq("{{< image id=\"#{image.public_id}\" caption=\"A beautiful sunset\" >}}")
      end
    end

    context "without a caption" do
      let(:caption) { "" }

      it "renders a Hugo image shortcode with only the id" do
        result = described_class.new(block).to_html
        expect(result).to eq("{{< image id=\"#{image.public_id}\" >}}")
      end
    end

    context "with nil caption" do
      let(:caption) { nil }

      it "renders a Hugo image shortcode with only the id" do
        result = described_class.new(block).to_html
        expect(result).to eq("{{< image id=\"#{image.public_id}\" >}}")
      end
    end

    context "with blank image_id" do
      let(:caption) { "" }
      let(:block) do
        Blocks::Image.new(id: "img123", image_id: nil, caption: caption)
      end

      it "returns an empty string" do
        expect(described_class.new(block).to_html).to eq("")
      end
    end
  end
end
