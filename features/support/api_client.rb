class CucumberApiClient
  include Rack::Test::Methods

  attr_reader :last_json

  def app
    Rails.application
  end

  def auth_header(token)
    header("Authorization", "Bearer #{token}")
  end

  def json_request(method, path, body = nil)
    header("Content-Type", "application/json")
    if body
      send(method, path, body.to_json)
    else
      send(method, path)
    end
    @last_json = JSON.parse(last_response.body)
    last_response
  end

  def clear_auth
    header("Authorization", "")
  end
end

module ApiWorld
  def api
    @api ||= CucumberApiClient.new
  end

  def api_response
    api.last_response
  end

  def api_json
    api.last_json
  end

  def site_posts_path
    "/api/v1/sites/#{@current_site.public_id}/posts"
  end

  def site_pages_path
    "/api/v1/sites/#{@current_site.public_id}/pages"
  end

  def site_images_path
    "/api/v1/sites/#{@current_site.public_id}/images"
  end
end

World(ApiWorld)
