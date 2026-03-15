require 'faraday'

class RemoteImageCreator
  class Error < StandardError; end

  def initialize(site, imageable)
    @site = site
    @imageable = imageable
  end

  FETCH_TIMEOUT_IN_SECONDS = 5

  def create_from(source_url)
    image_data = image_data_for(source_url:)

    image = @site.images.new(source_url:, imageable: @imageable)
    image.file.attach(io: image_data, filename: File.basename(source_url))

    return nil unless image.save

    image
  end

  private

  def image_data_for(source_url:)
    response = get(source_url, timeout: FETCH_TIMEOUT_IN_SECONDS)

    raise Error, "Failed to fetch image from #{source_url}. Status: #{response.status}" unless response.success?

    StringIO.new(response.body)
  end

  def get(url, timeout:)
    connection = Faraday.new do |f|
      f.response :follow_redirects
      f.options.timeout = timeout
      f.options.open_timeout = timeout
    end

    connection.get(url)
  rescue Faraday::Error => e
    raise Error, "Failed to fetch image from #{url}. Error: #{e.message}"
  end
end
