require "rails_helper"

RSpec.describe OpenLibrary::SearchResult do
  describe "#initialize" do
    let(:data) do
      {
        "title" => "The Hobbit",
        "author_name" => ["J.R.R. Tolkien", "John Ronald Reuel Tolkien"],
        "isbn" => %w[9780547928227 0618260307],
        "key" => "/works/OL262758W",
        "cover_i" => 6_979_861
      }
    end

    it "extracts book data" do
      result = described_class.new(data)

      expect(result.title).to eq("The Hobbit")
      expect(result.author).to eq("J.R.R. Tolkien")
      expect(result.isbn).to eq("9780547928227")
      expect(result.key).to eq("/works/OL262758W")
      expect(result.cover_id).to eq(6_979_861)
    end

    it "handles missing author" do
      data_without_author = data.except("author_name")
      result = described_class.new(data_without_author)

      expect(result.author).to be_nil
    end

    it "handles missing ISBN" do
      data_without_isbn = data.except("isbn")
      result = described_class.new(data_without_isbn)

      expect(result.isbn).to be_nil
    end
  end

  describe "#cover_url" do
    it "returns the cover URL when cover_id is present" do
      result = described_class.new({ "cover_i" => 6_979_861 })

      expect(result.cover_url).to eq("https://covers.openlibrary.org/b/id/6979861-M.jpg")
    end

    it "accepts a custom size" do
      result = described_class.new({ "cover_i" => 6_979_861 })

      expect(result.cover_url(size: :L)).to eq("https://covers.openlibrary.org/b/id/6979861-L.jpg")
    end

    it "returns nil when cover_id is not present" do
      result = described_class.new({})

      expect(result.cover_url).to be_nil
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      data = {
        "title" => "The Hobbit",
        "author_name" => ["J.R.R. Tolkien"],
        "isbn" => ["9780547928227"],
        "key" => "/works/OL262758W",
        "cover_i" => 6_979_861
      }
      result = described_class.new(data)

      expect(result.to_h).to eq({
                                  title: "The Hobbit",
                                  author: "J.R.R. Tolkien",
                                  isbn: "9780547928227",
                                  key: "/works/OL262758W",
                                  cover_url: "https://covers.openlibrary.org/b/id/6979861-M.jpg"
                                })
    end
  end
end
