module JekyllImporter
  class ContentConverter
    include HtmlCleaner
    include TextBlockConverters

    LOCAL_IMAGE_PATTERN = %r{/assets/\d{4}/\d{2}/[^"'\s<>]+\.(?:jpe?g|png|gif|webp)}i
    EXTERNAL_IMAGE_PATTERN = %r{https?://[^"'\s<>]+\.(?:jpe?g|png|gif|webp)}i
    IMG_TAG_PATTERN = %r{<img\s[^>]*src=["']([^"']+)["'][^>]*/?>}i
    SRCSET_ATTR_PATTERN = /\s+srcset=["'][^"']*["']/i
    SIZES_ATTR_PATTERN = /\s+sizes=["'][^"']*["']/i

    HTML_LINKED_IMAGE_PATTERN = %r{<a\s[^>]*href=["']([^"']+)["'][^>]*>\s*<img\s[^>]*src=["']([^"']+)["'][^>]*/?>.*?</a>}im
    WP_CAPTION_PATTERN = %r{<div\s[^>]*id=["']attachment_[^"']*["'][^>]*>(.*?)</div>}im
    CAPTION_P_PATTERN = %r{<p\s[^>]*id=["']caption[^"']*["'][^>]*>(.*?)</p>}im

    ELEMENT_MATCHERS = [
      [/\A<img\s/i, :convert_image],
      [/\A!\[[^\]]*\]\([^)]+\)\z/, :convert_markdown_image],
      [/\A<pre[\s>]/i, :convert_pre_block],
      [/\A```/, :convert_fenced_code],
      [/\A\[(?:php|code|ruby|java|python|css|html|javascript|xml|sql|bash)\]/i, :convert_bbcode_block],
      [/\A<blockquote/i, :convert_blockquote],
      [/\A> /, :convert_markdown_blockquote],
      [/\A\[table\]/i, :convert_table_shortcode],
      [/\A<[uo]l[\s>]/i, :convert_html_list],
      [/\A<embed\s/i, :convert_embed],
      [/\A\#{1,6}\s/, :convert_header],
      [/\A\d+\.\s/, :convert_ordered_list],
      [/\A\s{0,3}[*-]\s?/, :convert_unordered_list]
    ].freeze

    def initialize(assets_base_path:, image_uploader:)
      @image_resolver = ImageResolver.new(assets_base_path: assets_base_path, image_uploader: image_uploader)
      @splitter = ElementSplitter.new
    end

    def convert(raw_content)
      return [] if raw_content.blank?

      content = raw_content.gsub("\\_", "_")
      content = normalize_wp_image_urls(content)
      content = content.gsub(SRCSET_ATTR_PATTERN, "").gsub(SIZES_ATTR_PATTERN, "")
      content = extract_wp_captions(content)
      content = unwrap_linked_images(content)
      @splitter.split(content).flat_map { |el| convert_element(el) }.compact
    end

    def extract_image_paths(raw_content)
      content = normalize_wp_image_urls(raw_content)
      paths = []
      content.scan(IMG_TAG_PATTERN) { |match| paths << match[0] }
      content.scan(/!\[[^\]]*\]\(([^)]+)\)/) { |match| paths << match[0] }
      paths.grep(LOCAL_IMAGE_PATTERN).uniq
    end

    private

    def normalize_wp_image_urls(content)
      content.gsub(
        %r{https?://[^"'\s<>]+/wp-content/uploads/(?:sites/\d+/)?(\d{4}/\d{2}/[^"'\s<>]+\.(?:jpe?g|png|gif|webp))}i,
        '/assets/\1'
      )
    end

    def extract_wp_captions(content)
      content.gsub(WP_CAPTION_PATTERN) do
        inner = Regexp.last_match(1)
        caption_match = inner.match(CAPTION_P_PATTERN)
        if caption_match
          caption_text = caption_match[1].gsub(/<[^>]+>/, "").strip
          inner_without_caption = inner.sub(CAPTION_P_PATTERN, "").strip
          inner_without_caption.sub(/(\/?>)/, %( data-caption="#{caption_text}"\\1))
        else
          inner
        end
      end
    end

    def unwrap_linked_images(content)
      # HTML <a href><img></a> — use href if it points to an image
      result = content.gsub(HTML_LINKED_IMAGE_PATTERN) do
        href = Regexp.last_match(1)
        img_src = Regexp.last_match(2)
        if href.match?(/\.(?:jpe?g|png|gif|webp)(?:\?|$)/i)
          # Replace img src with the full-size href
          "<img src=\"#{href}\" />"
        else
          "<img src=\"#{img_src}\" />"
        end
      end

      # Markdown [![]()](url)
      result.gsub(%r{\[(<img\s[^>]*/?>)\]\(([^)]+)\)}) do
        "#{Regexp.last_match(1)}\n\n<a href=\"#{Regexp.last_match(2)}\">#{Regexp.last_match(2)}</a>"
      end
    end

    def convert_element(element)
      return nil if element.blank?

      # Check for Vimeo links in paragraphs
      if element.match?(VIMEO_PATTERN) && !element.match?(/\A</) && !element.match?(/\A[#*\-\d]/)
        vimeo_result = convert_vimeo_link(element.strip)
        return vimeo_result if vimeo_result
      end

      converter = ELEMENT_MATCHERS.find { |pattern, _| element.match?(pattern) }&.last
      converter ? send(converter, element) : convert_paragraph_or_mixed(element)
    end

    def convert_image(element)
      src = element.match(IMG_TAG_PATTERN)&.captures&.first
      return nil unless src

      caption = element.match(/data-caption=["']([^"']+)["']/i)&.captures&.first
      [image_block_from_src(src, caption: caption)]
    end

    def convert_markdown_image(element)
      match = element.match(/!\[[^\]]*\]\(([^)]+)\)/)
      match ? [image_block_from_src(match[1])] : nil
    end

    def convert_paragraph_or_mixed(element)
      return nil if element.blank?
      return [{ type: "paragraph", text: clean_html(element) }] unless element.match?(IMG_TAG_PATTERN)

      interleave_text_and_images(element)
    end

    def interleave_text_and_images(element)
      parts = element.split(IMG_TAG_PATTERN)
      srcs = element.scan(IMG_TAG_PATTERN).flatten

      parts.each_with_index.flat_map do |part, i|
        blocks = []
        text = clean_html(part.strip)
        blocks << { type: "paragraph", text: text } unless text.empty?
        blocks << image_block_from_src(srcs[i]) if i < srcs.length
        blocks
      end.compact
    end

    def image_block_from_src(src, caption: nil)
      if src.match?(LOCAL_IMAGE_PATTERN)
        block = @image_resolver.resolve_and_upload(src)
        block[:caption] = caption if caption && block[:type] == "image"
        return block
      end

      nil if src.match?(EXTERNAL_IMAGE_PATTERN)
    end
  end
end
