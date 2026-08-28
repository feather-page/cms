describe Image::Variants do
  describe ".filename_for" do
    it "turns a webp variant key into a filename" do
      expect(described_class.filename_for(:mobile_x1_webp)).to eq("mobile_x1.webp")
    end

    it "turns the jpg variant key into a filename" do
      expect(described_class.filename_for(:desktop_x1_jpg)).to eq("desktop_x1.jpg")
    end

    it "raises for an unknown variant key" do
      expect { described_class.filename_for(:desktop_x1_png) }.to raise_error(ArgumentError)
    end
  end

  describe ".key_from" do
    it "builds a known variant key from name and extension" do
      expect(described_class.key_from("desktop_x2", "webp")).to eq(:desktop_x2_webp)
    end

    it "returns nil for an unknown combination" do
      expect(described_class.key_from("desktop_x2", "png")).to be_nil
    end

    it "returns nil for a size that has no jpg variant" do
      expect(described_class.key_from("mobile_x1", "jpg")).to be_nil
    end
  end

  describe ".content_type_for" do
    it "reports jpeg for the jpg variant" do
      expect(described_class.content_type_for(:desktop_x1_jpg)).to eq("image/jpeg")
    end

    it "reports webp for webp variants" do
      expect(described_class.content_type_for(:mobile_x1_webp)).to eq("image/webp")
    end
  end

  describe "filename and key" do
    it "round-trips every known variant key" do
      described_class.each_key do |key|
        name, extension = described_class.filename_for(key).split(".")

        expect(described_class.key_from(name, extension)).to eq(key)
      end
    end
  end
end
