require "uri"

module JekyllImporter
  class JekyllParser
    SKIP_PAGES = %w[README.md 404.html index.markdown licence.md].freeze

    def initialize(site_path)
      @site_path = Pathname.new(site_path)
    end

    def post_files
      posts_dir = @site_path.join("_posts")
      return [] unless posts_dir.exist?

      Dir.glob(posts_dir.join("*.md"))
    end

    def page_files
      files = Dir.glob(@site_path.join("*.md")) + Dir.glob(@site_path.join("*.html"))
      files
        .reject { |f| SKIP_PAGES.include?(File.basename(f)) }
        .select { |f| page_layout?(f) }
    end

    def parse(file)
      raw = File.read(file)
      raw = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      return nil unless raw.start_with?("---")

      parts = raw.split("---", 3)
      return nil if parts.size < 3

      front_matter = YAML.safe_load(parts[1], permitted_classes: [Date, Time])
      [front_matter, parts[2].strip]
    rescue Psych::SyntaxError
      nil
    end

    def extract_post_params(front_matter, blocks)
      params = {
        title: front_matter["title"],
        slug: extract_slug(front_matter["permalink"]),
        draft: false,
        content: blocks
      }
      params[:publish_at] = front_matter["date"] if front_matter["date"]
      all_tags = Array(front_matter["categories"]) + Array(front_matter["tags"])
      params[:tags] = all_tags.join(", ") if all_tags.any?
      params
    end

    def extract_page_params(file, front_matter, blocks)
      {
        title: front_matter["title"],
        slug: page_slug(file, front_matter),
        content: blocks
      }
    end

    private

    def page_layout?(file)
      result = parse(file)
      result&.first&.dig("layout") == "page"
    end

    def extract_slug(permalink)
      return nil unless permalink

      segments = permalink.chomp("/").split("/").reject(&:empty?)
      raw_slug = segments.last
      return nil unless raw_slug

      "/#{sanitize_slug(raw_slug)}"
    end

    def sanitize_slug(raw)
      decoded = URI.decode_www_form_component(raw)
      decoded.downcase
             .tr("_", "-")
             .gsub(/[^a-z0-9-]/, "-")
             .gsub(/-{2,}/, "-")
             .gsub(/\A-|-\z/, "")
    end

    def page_slug(file, front_matter)
      if front_matter["permalink"]
        permalink = front_matter["permalink"].chomp("/")
        return permalink.start_with?("/") ? permalink : "/#{permalink}"
      end

      "/#{File.basename(file, File.extname(file))}"
    end
  end
end
