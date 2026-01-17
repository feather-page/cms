module OpenLibrary
  class SearchQuery
    TIMEOUT_SECONDS = 5

    def initialize(query, limit:)
      @query = query
      @limit = limit
    end

    def execute
      response = fetch_results
      parse_response(response)
    end

    private

    attr_reader :query, :limit

    def fetch_results
      connection.get("/search.json", q: query, limit:)
    end

    def parse_response(response)
      return [] unless response.success?

      JSON.parse(response.body)["docs"].map { |doc| SearchResult.new(doc) }
    end

    def connection
      Faraday.new(url: Client::BASE_URL) do |f|
        f.options.timeout = TIMEOUT_SECONDS
      end
    end
  end
end
