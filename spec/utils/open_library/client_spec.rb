require "rails_helper"

RSpec.describe OpenLibrary::Client do
  describe "#search" do
    it "delegates to SearchQuery" do
      search_query = instance_double(OpenLibrary::SearchQuery, execute: [])
      allow(OpenLibrary::SearchQuery).to receive(:new).and_return(search_query)

      described_class.new.search("The Hobbit")

      expect(OpenLibrary::SearchQuery).to have_received(:new).with("The Hobbit", limit: 10)
      expect(search_query).to have_received(:execute)
    end

    it "accepts custom limit" do
      search_query = instance_double(OpenLibrary::SearchQuery, execute: [])
      allow(OpenLibrary::SearchQuery).to receive(:new).and_return(search_query)

      described_class.new.search("The Hobbit", limit: 5)

      expect(OpenLibrary::SearchQuery).to have_received(:new).with("The Hobbit", limit: 5)
    end
  end

  describe "#cover_url" do
    it "returns the cover URL for an ISBN" do
      client = described_class.new

      url = client.cover_url(isbn: "9780547928227", size: :L)

      expect(url).to eq("https://covers.openlibrary.org/b/isbn/9780547928227-L.jpg")
    end

    it "defaults to medium size" do
      client = described_class.new

      url = client.cover_url(isbn: "9780547928227")

      expect(url).to eq("https://covers.openlibrary.org/b/isbn/9780547928227-M.jpg")
    end
  end
end
