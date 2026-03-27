describe Hugo::ImageVariant do
  let(:image) { instance_double(Image, public_id: "abc123") }

  describe "#public_path" do
    it "returns the webp public path for a webp variant" do
      variant = described_class.new(image:, variant_name: :mobile_x1_webp)
      expect(variant.public_path).to eq("/images/abc123/mobile_x1.webp")
    end

    it "returns the jpg public path for a jpg variant" do
      variant = described_class.new(image:, variant_name: :desktop_x1_jpg)
      expect(variant.public_path).to eq("/images/abc123/desktop_x1.jpg")
    end

    it "returns the webp public path for desktop_x2_webp" do
      variant = described_class.new(image:, variant_name: :desktop_x2_webp)
      expect(variant.public_path).to eq("/images/abc123/desktop_x2.webp")
    end
  end

  describe "#static_path" do
    it "prepends 'static' to the public path" do
      variant = described_class.new(image:, variant_name: :mobile_x1_webp)
      expect(variant.static_path).to eq("static/images/abc123/mobile_x1.webp")
    end
  end

  describe ".all_for" do
    it "returns a variant for each key in Image::Variants" do
      variants = described_class.all_for(image)

      expect(variants.length).to eq(Image::Variants.keys.length)
      expect(variants).to all(be_a(described_class))
    end

    it "includes both webp and jpg variants" do
      variants = described_class.all_for(image)
      extensions = variants.map(&:public_path).map { |p| File.extname(p) }

      expect(extensions).to include(".webp")
      expect(extensions).to include(".jpg")
    end
  end
end
