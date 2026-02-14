# frozen_string_literal: true

describe Hugo::ImageVariant do
  let(:image) { create(:image) }

  describe "#build_path" do
    it "returns the static build path" do
      variant = described_class.new(image, :mobile_x1_webp)

      expect(variant.build_path).to eq("static/images/#{image.public_id}/mobile_x1.webp")
    end
  end

  describe "#public_path" do
    it "returns the public URL path for webp variant" do
      variant = described_class.new(image, :mobile_x1_webp)

      expect(variant.public_path).to eq("/images/#{image.public_id}/mobile_x1.webp")
    end

    it "returns the public URL path for jpg variant" do
      variant = described_class.new(image, :desktop_x2_jpg)

      expect(variant.public_path).to eq("/images/#{image.public_id}/desktop_x2.jpg")
    end
  end
end
