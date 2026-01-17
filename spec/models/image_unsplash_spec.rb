require 'rails_helper'

RSpec.describe Image, type: :model do
  describe "unsplash methods" do
    let(:site) { create(:site) }

    context "with unsplash data" do
      let(:image) do
        create(:image, site: site, unsplash_data: {
          "photographer_name" => "John Doe",
          "photographer_url" => "https://unsplash.com/@johndoe"
        })
      end

      describe "#unsplash?" do
        it "returns true when unsplash_data is present" do
          expect(image.unsplash?).to be true
        end
      end

      describe "#unsplash_photographer_name" do
        it "returns the photographer name" do
          expect(image.unsplash_photographer_name).to eq("John Doe")
        end
      end

      describe "#unsplash_photographer_url" do
        it "returns the photographer URL" do
          expect(image.unsplash_photographer_url).to eq("https://unsplash.com/@johndoe")
        end
      end
    end

    context "without unsplash data" do
      let(:image) { create(:image, site: site, unsplash_data: nil) }

      describe "#unsplash?" do
        it "returns false when unsplash_data is nil" do
          expect(image.unsplash?).to be false
        end
      end

      describe "#unsplash_photographer_name" do
        it "returns nil" do
          expect(image.unsplash_photographer_name).to be_nil
        end
      end

      describe "#unsplash_photographer_url" do
        it "returns nil" do
          expect(image.unsplash_photographer_url).to be_nil
        end
      end
    end
  end
end
