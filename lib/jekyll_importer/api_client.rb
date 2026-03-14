require "net/http"
require "json"

module JekyllImporter
  class ApiClient
    class ApiError < StandardError; end

    # 300 requests per 5 minutes = 1 req/s, use 1.1s to stay safely under the limit
    REQUEST_INTERVAL = 1.1

    def initialize(base_url:, token:, site_id:)
      @base_url = base_url.chomp("/")
      @token = token
      @site_id = site_id
      @last_request_at = nil
    end

    def upload_image(file_path)
      uri = images_uri
      boundary = "----JekyllImport#{SecureRandom.hex(16)}"
      body = read_multipart_body(file_path, boundary)
      request = multipart_request(uri, boundary, body)
      parse_response(execute(uri, request)).dig("data", "id")
    end

    def find_image(public_id)
      uri = URI("#{images_uri}/#{public_id}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      parse_response(execute(uri, request))
    end

    def create_post(params)
      json_request(:post, posts_uri, { post: params })
    end

    def create_page(params)
      json_request(:post, pages_uri, { page: params })
    end

    def list_posts(page: 1)
      get_request(URI("#{posts_uri}?api_page=#{page}"))
    end

    def list_pages(page: 1)
      get_request(URI("#{pages_uri}?api_page=#{page}"))
    end

    def delete_post(public_id)
      delete_request(URI("#{posts_uri}/#{public_id}"))
    end

    def delete_page(public_id)
      delete_request(URI("#{pages_uri}/#{public_id}"))
    end

    private

    def images_uri = URI("#{@base_url}/api/v1/sites/#{@site_id}/images")
    def posts_uri = URI("#{@base_url}/api/v1/sites/#{@site_id}/posts")
    def pages_uri = URI("#{@base_url}/api/v1/sites/#{@site_id}/pages")

    def multipart_request(uri, boundary, body)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = body
      request
    end

    def read_multipart_body(file_path, boundary)
      file_data = File.binread(file_path)
      filename = File.basename(file_path)
      build_multipart_body(boundary, file_data, filename, mime_type_for(filename))
    end

    def get_request(uri)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      parse_response(execute(uri, request))
    end

    def delete_request(uri)
      request = Net::HTTP::Delete.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      parse_response(execute(uri, request))
    end

    def json_request(method, uri, body)
      request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Patch.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      parse_response(execute(uri, request))
    end

    def execute(uri, request)
      throttle
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 30
      http.read_timeout = 120
      http.request(request)
    end

    def throttle
      if @last_request_at
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request_at
        sleep(REQUEST_INTERVAL - elapsed) if elapsed < REQUEST_INTERVAL
      end
      @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def parse_response(response)
      body = response.body.to_s.strip
      raise ApiError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      return {} if body.empty?

      JSON.parse(body)
    end

    def build_multipart_body(boundary, file_data, filename, content_type)
      body = +"".b
      body << "--#{boundary}\r\n".b
      body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n".b
      body << "Content-Type: #{content_type}\r\n\r\n".b
      body << file_data
      body << "\r\n--#{boundary}--\r\n".b
    end

    def mime_type_for(filename)
      case File.extname(filename).downcase
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".png" then "image/png"
      when ".gif" then "image/gif"
      when ".webp" then "image/webp"
      else "application/octet-stream"
      end
    end
  end
end
