# frozen_string_literal: true

describe Blocks::Renderer::Image do
  let(:image) { create(:image) }
  let(:block) do
    Blocks::Image.new(id: "A70r8-SIog", image_id: image.public_id, caption:)
  end
  let(:routes) do
    instance_double(StaticSite::Routes).tap do |r|
      allow(r).to receive(:image_url).with(image, :desktop_x1_jpg)
        .and_return("/images/#{image.public_id}/desktop_x1.jpg")
      allow(r).to receive(:image_url).with(image, anything)
        .and_return("/images/#{image.public_id}/mobile_x1.webp")
      allow(r).to receive(:image_srcset).with(image)
        .and_return("/images/#{image.public_id}/mobile_x1.webp 430w, /images/#{image.public_id}/desktop_x1.webp 1200w")
    end
  end

  before do
    allow(image).to receive_messages(width: 10, height: 10)
    allow(Image).to receive(:find).with(image.public_id).and_return(image)
  end

  describe "#to_html" do
    let(:image_html) { described_class.new(block, routes:).to_html }

    context "with a caption" do
      let(:caption) { "A beautiful image" }

      it "returns the html with alt-attribute and caption" do
        expect(image_html).to include("<figcaption>#{caption}</figcaption>")
        expect(image_html).to include('alt="A beautiful image"')
      end

      it "uses routes for constructing image paths" do
        expect(image_html).to include("/images/#{image.public_id}/mobile_x1.webp")
      end

      it "includes webp type in markup" do
        expect(image_html).to include('type="image/webp"')
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