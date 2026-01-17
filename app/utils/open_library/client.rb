module OpenLibrary
  class Client
    BASE_URL = "https://openlibrary.org".freeze
    COVERS_URL = "https://covers.openlibrary.org".freeze

    def search(query, limit: 10)
      SearchQuery.new(query, limit:).execute
    end

    def cover_url(isbn:, size: :M)
      "#{COVERS_URL}/b/isbn/#{isbn}-#{size}.jpg"
    end
  end
end
