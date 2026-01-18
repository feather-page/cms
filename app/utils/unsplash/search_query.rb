module Unsplash
  class SearchQuery
    TIMEOUT_SECONDS = 5

    def initialize(query, page:, per_page:, access_key:)
      @query = query
      @page = page
      @per_page = per_page
      @access_key = access_key
    end

    def execute
      response = fetch_results
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("Unsplash search failed: #{e.message}")
      []
    end

    private

    attr_reader :query, :page, :per_page, :access_key

    def fetch_results
      connection.get("/search/photos", params)
    end

    def params
      { query:, page:, per_page:, client_id: access_key }
    end

    def parse_response(response)
      return [] unless response.success?

      JSON.parse(response.body)["results"].map { |r| SearchResult.new(r) }
    end

    def connection
      Faraday.new(url: Client::BASE_URL) do |f|
        f.options.timeout = TIMEOUT_SECONDS
      end
    end
  end
end
