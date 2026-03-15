require "rails_helper"

RSpec.describe StaticSite::ImageCollector do
  let(:site) { create(:site) }

  subject(:collected_images) { described_class.new(site).to_a }

  describe "#to_a" do
    it "returns an empty array when no images exist" do
      expect(collected_images).to eq([])
    end

    context "with content images" do
      it "includes assigned images" do
        post = create(:post, site:)
        image = create(:image, site:, imageable: post)

        expect(collected_images).to include(image)
      end

      it "excludes unassigned images" do
        create(:image, site:, imageable: nil)

        expect(collected_images).to be_empty
      end
    end

    context "with header images" do
      it "includes post header images" do
        image = create(:image, site:)
        create(:post, site:, header_image: image)

        expect(collected_images).to include(image)
      end

      it "includes page header images" do
        image = create(:image, site:)
        create(:page, site:, header_image: image)

        expect(collected_images).to include(image)
      end

      it "includes project header images" do
        image = create(:image, site:)
        create(:project, site:, header_image: image)

        expect(collected_images).to include(image)
      end
    end

    context "with thumbnail images" do
      it "includes project thumbnail images" do
        project = create(:project, :with_thumbnail_image, site:)

        expect(collected_images).to include(project.thumbnail_image)
      end
    end

    context "with book cover images" do
      it "includes book cover images" do
        book = create(:book, :with_cover, site:)

        expect(collected_images).to include(book.cover_image)
      end
    end

    context "deduplication" do
      it "does not return the same image twice" do
        post = create(:post, site:)
        image = create(:image, site:, imageable: post)
        post.update!(header_image: image)

        expect(collected_images.count(image)).to eq(1)
      end
    end
  end
end
