require "rails_helper"

RSpec.describe Unsplash::Client do
  describe "#search" do
    it "delegates to SearchQuery" do
      search_query = instance_double(Unsplash::SearchQuery, execute: [])
      allow(Unsplash::SearchQuery).to receive(:new).and_return(search_query)

      described_class.new.search("nature")

      expect(Unsplash::SearchQuery).to have_received(:new).with(
        "nature",
        page: 1,
        per_page: 12,
        access_key: anything
      )
      expect(search_query).to have_received(:execute)
    end

    it "accepts custom page and per_page" do
      search_query = instance_double(Unsplash::SearchQuery, execute: [])
      allow(Unsplash::SearchQuery).to receive(:new).and_return(search_query)

      described_class.new.search("nature", page: 2, per_page: 24)

      expect(Unsplash::SearchQuery).to have_received(:new).with(
        "nature",
        page: 2,
        per_page: 24,
        access_key: anything
      )
    end
  end

  describe "#photo" do
    it "delegates to PhotoQuery" do
      photo_query = instance_double(Unsplash::PhotoQuery, execute: nil)
      allow(Unsplash::PhotoQuery).to receive(:new).and_return(photo_query)

      described_class.new.photo("abc123")

      expect(Unsplash::PhotoQuery).to have_received(:new).with(
        "abc123",
        access_key: anything
      )
      expect(photo_query).to have_received(:execute)
    end
  end
end
