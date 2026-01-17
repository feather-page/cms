module OpenLibrary
  class SearchResult
    attr_reader :title, :author, :isbn, :key, :cover_id

    def initialize(data)
      @title = data["title"]
      @author = Array(data["author_name"]).first
      @isbn = Array(data["isbn"]).first
      @key = data["key"]
      @cover_id = data["cover_i"]
    end

    def cover_url(size: :M)
      return nil unless cover_id

      "#{Client::COVERS_URL}/b/id/#{cover_id}-#{size}.jpg"
    end

    def to_h
      { title:, author:, isbn:, key:, cover_url: cover_url }
    end
  end
end
