require "rails_helper"

RSpec.describe Unsplash::SearchQuery do
  let(:access_key) { "test_access_key" }
  let(:query) { described_class.new("nature", page: 1, per_page: 12, access_key:) }

  describe "#execute" do
    let(:response_body) do
      {
        "results" => [
          {
            "id" => "abc123",
            "description" => "A beautiful landscape",
            "alt_description" => "Mountains and trees",
            "urls" => { "thumb" => "https://example.com/thumb.jpg", "regular" => "https://example.com/regular.jpg" },
            "user" => { "name" => "John Doe", "links" => { "html" => "https://unsplash.com/@johndoe" } },
            "links" => { "download_location" => "https://api.unsplash.com/photos/abc123/download" }
          }
        ]
      }.to_json
    end

    it "returns search results on success" do
      stub_request(:get, "https://api.unsplash.com/search/photos")
        .with(query: { query: "nature", page: 1, per_page: 12, client_id: access_key })
        .to_return(status: 200, body: response_body)

      results = query.execute

      expect(results).to be_an(Array)
      expect(results.length).to eq(1)
      expect(results.first).to be_a(Unsplash::SearchResult)
      expect(results.first.id).to eq("abc123")
    end

    it "returns empty array on failure" do
      stub_request(:get, "https://api.unsplash.com/search/photos")
        .with(query: { query: "nature", page: 1, per_page: 12, client_id: access_key })
        .to_return(status: 500)

      results = query.execute

      expect(results).to eq([])
    end

    it "returns empty array on exception" do
      stub_request(:get, "https://api.unsplash.com/search/photos")
        .with(query: { query: "nature", page: 1, per_page: 12, client_id: access_key })
        .to_raise(StandardError.new("Network error"))

      expect(Rails.logger).to receive(:error).with("Unsplash search failed: Network error")

      results = query.execute

      expect(results).to eq([])
    end
  end
end
