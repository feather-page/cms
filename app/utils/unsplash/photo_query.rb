module Unsplash
  class PhotoQuery
    TIMEOUT_SECONDS = 5

    def initialize(id, access_key:)
      @id = id
      @access_key = access_key
    end

    def execute
      response = fetch_photo
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("Unsplash photo fetch failed: #{e.message}")
      nil
    end

    private

    attr_reader :id, :access_key

    def fetch_photo
      connection.get("/photos/#{id}", client_id: access_key)
    end

    def parse_response(response)
      return nil unless response.success?

      SearchResult.new(JSON.parse(response.body))
    end

    def connection
      Faraday.new(url: Client::BASE_URL) do |f|
        f.options.timeout = TIMEOUT_SECONDS
      end
    end
  end
end
