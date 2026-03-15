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

  MAX_REDIRECTS = 3

  def get(url, timeout:, redirects: MAX_REDIRECTS)
    connection = Faraday.new do |f|
      f.options.timeout = timeout
      f.options.open_timeout = timeout
    end

    response = connection.get(url)

    location = response.headers["location"]
    if response.status.in?([301, 302, 303, 307, 308]) && redirects > 0 && location.present?
      return get(location, timeout:, redirects: redirects - 1)
    end

    response
  rescue Faraday::Error => e
    raise Error, "Failed to fetch image from #{url}. Error: #{e.message}"
  end
end
