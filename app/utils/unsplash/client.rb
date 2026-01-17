module Unsplash
  class Client
    BASE_URL = "https://api.unsplash.com".freeze

    def search(query, page: 1, per_page: 12)
      SearchQuery.new(query, page:, per_page:, access_key: credentials).execute
    end

    def photo(id)
      PhotoQuery.new(id, access_key: credentials).execute
    end

    private

    def credentials
      Rails.application.credentials.dig(:unsplash, :access_key) || ENV.fetch("UNSPLASH_ACCESS_KEY", nil)
    end
  end
end
