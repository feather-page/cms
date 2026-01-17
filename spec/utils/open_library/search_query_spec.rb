require "rails_helper"

RSpec.describe OpenLibrary::SearchQuery do
  describe "#execute" do
    let(:search_response) do
      {
        "docs" => [
          {
            "title" => "The Hobbit",
            "author_name" => ["J.R.R. Tolkien"],
            "isbn" => ["9780547928227"],
            "key" => "/works/OL262758W",
            "cover_i" => 6_979_861
          },
          {
            "title" => "The Lord of the Rings",
            "author_name" => ["J.R.R. Tolkien"],
            "isbn" => ["9780618640157"],
            "key" => "/works/OL27448W",
            "cover_i" => 8_474_650
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, "https://openlibrary.org/search.json")
        .with(query: { q: "Tolkien", limit: 10 })
        .to_return(status: 200, body: search_response)
    end

    it "returns search results" do
      results = described_class.new("Tolkien", limit: 10).execute

      expect(results.length).to eq(2)
      expect(results.first).to be_a(OpenLibrary::SearchResult)
      expect(results.first.title).to eq("The Hobbit")
      expect(results.first.author).to eq("J.R.R. Tolkien")
    end

    context "when the API returns an error" do
      before do
        stub_request(:get, "https://openlibrary.org/search.json")
          .with(query: { q: "error", limit: 10 })
          .to_return(status: 500)
      end

      it "returns an empty array" do
        results = described_class.new("error", limit: 10).execute

        expect(results).to eq([])
      end
    end
  end
end
