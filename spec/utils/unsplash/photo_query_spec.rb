require "rails_helper"

RSpec.describe Unsplash::PhotoQuery do
  let(:access_key) { "test_access_key" }
  let(:query) { described_class.new("abc123", access_key:) }

  describe "#execute" do
    let(:response_body) do
      {
        "id" => "abc123",
        "description" => "A beautiful landscape",
        "alt_description" => "Mountains and trees",
        "urls" => { "thumb" => "https://example.com/thumb.jpg", "regular" => "https://example.com/regular.jpg" },
        "user" => { "name" => "John Doe", "links" => { "html" => "https://unsplash.com/@johndoe" } },
        "links" => { "download_location" => "https://api.unsplash.com/photos/abc123/download" }
      }.to_json
    end

    it "returns a search result on success" do
      stub_request(:get, "https://api.unsplash.com/photos/abc123")
        .with(query: { client_id: access_key })
        .to_return(status: 200, body: response_body)

      result = query.execute

      expect(result).to be_a(Unsplash::SearchResult)
      expect(result.id).to eq("abc123")
    end

    it "returns nil on failure" do
      stub_request(:get, "https://api.unsplash.com/photos/abc123")
        .with(query: { client_id: access_key })
        .to_return(status: 404)

      result = query.execute

      expect(result).to be_nil
    end

    it "returns nil on exception" do
      stub_request(:get, "https://api.unsplash.com/photos/abc123")
        .with(query: { client_id: access_key })
        .to_raise(StandardError.new("Network error"))

      expect(Rails.logger).to receive(:error).with("Unsplash photo fetch failed: Network error")

      result = query.execute

      expect(result).to be_nil
    end
  end
end
