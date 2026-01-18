require "rails_helper"

RSpec.describe Unsplash::SearchResult do
  subject(:result) { described_class.new(data) }

  let(:data) do
    {
      "id" => "abc123",
      "description" => "A beautiful landscape",
      "alt_description" => "Mountains and trees",
      "urls" => {
        "thumb" => "https://example.com/thumb.jpg",
        "regular" => "https://example.com/regular.jpg"
      },
      "user" => {
        "name" => "John Doe",
        "links" => { "html" => "https://unsplash.com/@johndoe" }
      },
      "links" => {
        "download_location" => "https://api.unsplash.com/photos/abc123/download"
      }
    }
  end

  describe "#id" do
    it "returns the photo id" do
      expect(result.id).to eq("abc123")
    end
  end

  describe "#description" do
    it "returns the description" do
      expect(result.description).to eq("A beautiful landscape")
    end

    context "when description is nil" do
      let(:data) { super().merge("description" => nil) }

      it "falls back to alt_description" do
        expect(result.description).to eq("Mountains and trees")
      end
    end
  end

  describe "#thumbnail_url" do
    it "returns the thumb URL" do
      expect(result.thumbnail_url).to eq("https://example.com/thumb.jpg")
    end
  end

  describe "#full_url" do
    it "returns the regular URL" do
      expect(result.full_url).to eq("https://example.com/regular.jpg")
    end
  end

  describe "#download_location" do
    it "returns the download location" do
      expect(result.download_location).to eq("https://api.unsplash.com/photos/abc123/download")
    end
  end

  describe "#photographer" do
    it "returns photographer name and profile URL" do
      expect(result.photographer).to eq({
                                          name: "John Doe",
                                          profile_url: "https://unsplash.com/@johndoe"
                                        })
    end
  end

  describe "#unsplash_data" do
    it "returns data for storing with image" do
      expect(result.unsplash_data).to eq({
                                           "photographer_name" => "John Doe",
                                           "photographer_url" => "https://unsplash.com/@johndoe",
                                           "download_location" => "https://api.unsplash.com/photos/abc123/download"
                                         })
    end
  end
end
