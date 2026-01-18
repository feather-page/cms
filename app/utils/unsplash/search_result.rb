module Unsplash
  class SearchResult
    attr_reader :id, :description, :urls, :photographer

    def initialize(data)
      @id = data["id"]
      @description = data["description"] || data["alt_description"]
      @urls = extract_urls(data["urls"])
      @photographer = extract_photographer(data["user"])
      @links = data["links"]
    end

    def thumbnail_url
      @urls[:thumb]
    end

    def full_url
      @urls[:regular]
    end

    def download_location
      @links["download_location"]
    end

    def unsplash_data
      {
        "photographer_name" => @photographer[:name],
        "photographer_url" => @photographer[:profile_url],
        "download_location" => download_location
      }
    end

    private

    def extract_urls(urls)
      {
        thumb: urls["thumb"],
        regular: urls["regular"]
      }
    end

    def extract_photographer(user)
      {
        name: user["name"],
        profile_url: user["links"]["html"]
      }
    end
  end
end
