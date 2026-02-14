module JekyllImporter
  module TextBlockConverters
    YOUTUBE_PATTERN = %r{(?:youtube\.com/watch\?v=|youtube\.com/embed/|youtube\.com/v/|youtu\.be/)([a-zA-Z0-9_-]{11})}i
    VIMEO_PATTERN = %r{vimeo\.com/(?:video/)?(\d+)}i
    DEFUNCT_EMBED_HOSTS = %w[blip.tv polylog.tv].freeze

    private

    def convert_pre_block(element)
      code = element.sub(/\A<pre[^>]*>/i, "").sub(%r{</pre>\z}i, "").strip
      [{ type: "code", code: decode_entities(code) }]
    end

    def convert_fenced_code(element)
      lines = element.lines
      language = lines.first.strip.delete_prefix("```").strip
      language = "plaintext" if language.empty?
      [{ type: "code", code: (lines[1...-1]&.join || "").strip, language: language }]
    end

    def convert_bbcode_block(element)
      code = element.sub(/\A\[\w+\]/i, "").sub(%r{\[/\w+\]\z}i, "").strip
      [{ type: "code", code: decode_entities(code) }]
    end

    def convert_blockquote(element)
      text = element.sub(/\A<blockquote[^>]*>/i, "").sub(%r{</blockquote>\z}i, "")
      [{ type: "quote", text: clean_html(text.gsub(%r{</?p[^>]*>}i, "").strip), caption: "" }]
    end

    def convert_markdown_blockquote(element)
      text = element.lines.map { |l| l.sub(/\A>\s?/, "").strip }.join(" ")
      [{ type: "quote", text: clean_html(text), caption: "" }]
    end

    def convert_table_shortcode(element)
      lines = element.lines.reject { |l| l.strip.match?(/\A\[\/?\s*table\s*\]/i) }
      rows = lines.filter_map do |line|
        cells = line.strip.split(",").map(&:strip)
        cells if cells.any?(&:present?)
      end
      return [] if rows.empty?
      [{ type: "table", content: rows, with_headings: true }]
    end

    def convert_header(element)
      match = element.match(/\A(\#{1,6})\s+(.+)/)
      return [{ type: "paragraph", text: clean_html(element) }] unless match

      [{ type: "header", text: clean_html(match[2].strip), level: match[1].length.clamp(2, 4) }]
    end

    def convert_ordered_list(element)
      items = element.lines.filter_map { |l| clean_html(l.sub(/\A\s*\d+\.\s+/, "").strip).presence }
      [{ type: "list", items: items.map { |text| { "content" => text, "items" => [] } }, style: "ol" }]
    end

    def convert_unordered_list(element)
      items = element.lines.filter_map { |l| clean_html(l.sub(/\A\s*[*-]\s?/, "").strip).presence }
      [{ type: "list", items: items.map { |text| { "content" => text, "items" => [] } }, style: "ul" }]
    end

    def convert_html_list(element)
      style = element.match?(/\A<ol/i) ? "ol" : "ul"
      items = element.scan(%r{<li[^>]*>(.*?)</li>}im).flatten.filter_map do |li_content|
        text = clean_html(li_content.strip)
        text.presence
      end
      [{ type: "list", items: items.map { |text| { "content" => text, "items" => [] } }, style: style }]
    end

    def convert_embed(element)
      src = element.match(/src=["']([^"']+)["']/i)&.captures&.first
      return [convert_defunct_embed(element)] unless src

      if (match = src.match(YOUTUBE_PATTERN))
        [youtube_block(match[1])]
      elsif (match = src.match(VIMEO_PATTERN))
        [vimeo_block(match[1])]
      else
        [convert_defunct_embed(element)]
      end
    end

    def convert_vimeo_link(url)
      match = url.match(VIMEO_PATTERN)
      return nil unless match

      [vimeo_block(match[1])]
    end

    def youtube_block(video_id)
      {
        type: "embed",
        service: "youtube",
        source: "https://www.youtube.com/watch?v=#{video_id}",
        embed: "https://www.youtube-nocookie.com/embed/#{video_id}",
        caption: ""
      }
    end

    def vimeo_block(video_id)
      {
        type: "embed",
        service: "vimeo",
        source: "https://vimeo.com/#{video_id}",
        embed: "https://player.vimeo.com/video/#{video_id}",
        caption: ""
      }
    end

    def convert_defunct_embed(element)
      src = element.match(/src=["']([^"']+)["']/i)&.captures&.first || element
      { type: "paragraph", text: "<i>[Archived embed: #{src}]</i>" }
    end
  end
end
