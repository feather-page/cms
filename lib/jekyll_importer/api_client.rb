require "net/http"
require "json"

module JekyllImporter
  class ApiClient
    class ApiError < StandardError; end

    def initialize(base_url:, token:, site_id:)
      @base_url = base_url.chomp("/")
      @token = token
      @site_id = site_id
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

    def json_request(method, uri, body)
      request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Patch.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      parse_response(execute(uri, request))
    end

    def execute(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 30
      http.read_timeout = 120
      http.request(request)
    end

    def parse_response(response)
      parsed = JSON.parse(response.body)
      raise ApiError, parsed["error"] || "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed
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
