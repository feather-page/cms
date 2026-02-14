require "yaml"
require_relative "jekyll_importer/api_client"
require_relative "jekyll_importer/html_cleaner"
require_relative "jekyll_importer/text_block_converters"
require_relative "jekyll_importer/image_resolver"
require_relative "jekyll_importer/element_splitter"
require_relative "jekyll_importer/content_converter"
require_relative "jekyll_importer/jekyll_parser"

module JekyllImporter
  class Importer
    def initialize(site_path:, api_token:, site_id:, base_url: "http://localhost:3000")
      @site_path = Pathname.new(site_path)
      @api_client = ApiClient.new(base_url: base_url, token: api_token, site_id: site_id)
      @parser = JekyllParser.new(site_path)
      @image_cache = {}
      @stats = { posts: 0, pages: 0, images: 0, errors: [] }
    end

    def run
      $stdout.puts "Jekyll Import: #{@site_path}"
      $stdout.puts "=" * 60

      @converter = ContentConverter.new(
        assets_base_path: @site_path,
        image_uploader: method(:upload_image)
      )
      @image_resolver = ImageResolver.new(
        assets_base_path: @site_path,
        image_uploader: method(:upload_image)
      )

      import_posts
      import_pages
      print_summary
    end

    private

    def import_posts
      files = @parser.post_files
      $stdout.puts "\nImporting #{files.size} posts..."

      files.each_with_index do |file, index|
        import_post(file, index, files.size)
      end
    end

    def import_post(file, index, total)
      front_matter, content = @parser.parse(file)
      return record_parse_error(file) unless front_matter

      log_progress(index, total, front_matter["title"])
      blocks = @converter.convert(content)
      params = @parser.extract_post_params(front_matter, blocks)
      thumbnail_id = resolve_thumbnail(front_matter)
      params[:thumbnail_image_id] = thumbnail_id if thumbnail_id
      @api_client.create_post(params)
      @stats[:posts] += 1
    rescue ApiClient::ApiError, StandardError => e
      record_error("Post", front_matter&.dig("title") || File.basename(file), e)
    end

    def import_pages
      files = @parser.page_files
      $stdout.puts "\n\nImporting #{files.size} pages..."

      files.each_with_index do |file, index|
        import_page(file, index, files.size)
      end
    end

    def import_page(file, index, total)
      front_matter, content = @parser.parse(file)
      return record_parse_error(file) unless front_matter

      log_progress(index, total, front_matter["title"])
      blocks = @converter.convert(content)
      params = @parser.extract_page_params(file, front_matter, blocks)
      @api_client.create_page(params)
      @stats[:pages] += 1
    rescue ApiClient::ApiError, StandardError => e
      record_error("Page", front_matter&.dig("title") || File.basename(file), e)
    end

    WP_CONTENT_PATTERN = %r{https?://[^"'\s<>]+/wp-content/uploads/(?:sites/\d+/)?(\d{4}/\d{2}/[^"'\s<>]+\.(?:jpe?g|png|gif|webp))}i

    def resolve_thumbnail(front_matter)
      url = front_matter.dig("thumbnail")&.first
      return nil unless url

      src = url.gsub(WP_CONTENT_PATTERN, '/assets/\1')
      return nil unless src.start_with?("/assets/")

      result = @image_resolver.resolve_and_upload(src)
      result[:image_id]
    end

    def upload_image(file_path)
      return @image_cache[file_path] if @image_cache.key?(file_path)

      image_id = @api_client.upload_image(file_path)
      @image_cache[file_path] = image_id
      @stats[:images] += 1
      image_id
    rescue ApiClient::ApiError => e
      record_error("Image", File.basename(file_path), e)
      nil
    end

    def log_progress(index, total, title)
      $stdout.print "\r  [#{index + 1}/#{total}] #{title&.truncate(50)}"
    end

    def record_parse_error(file)
      @stats[:errors] << "Parse error: #{File.basename(file)}"
    end

    def record_error(kind, name, error)
      @stats[:errors] << "#{kind} '#{name}': #{error.message}"
      warn "\n  ERROR: #{error.message}"
    end

    def print_summary
      lines = [
        "\n\n#{'=' * 60}",
        "Import Complete!",
        "  Posts:  #{@stats[:posts]}",
        "  Pages:  #{@stats[:pages]}",
        "  Images: #{@stats[:images]}"
      ]
      print_errors(lines) if @stats[:errors].any?
      lines.each { |l| $stdout.puts l }
    end

    def print_errors(lines)
      lines << "\n  Errors (#{@stats[:errors].size}):"
      @stats[:errors].each { |e| lines << "    - #{e}" }
    end
  end
end
