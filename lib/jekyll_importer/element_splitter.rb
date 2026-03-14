module JekyllImporter
  class ElementSplitter
    IMG_TAG_PATTERN = %r{<img\s[^>]*src=["']([^"']+)["'][^>]*/?>}i

    def split(content)
      @elements = []
      @current = +""

      content.each_line { |line| process_line(line) }
      flush_current
      @elements
    end

    private

    def process_line(line)
      stripped = line.strip
      return blank_line if stripped.empty?

      if inside_markdown_blockquote?
        if stripped.start_with?(">")
          @current << line
          return
        else
          flush_current
        end
      end

      handler = detect_handler(stripped)
      handler ? send(handler, line, stripped) : (@current << line)
    end

    def detect_handler(stripped)
      return :handle_image if standalone_image?(stripped)
      return :handle_block_continuation if inside_block?
      return :handle_markdown_blockquote if stripped.start_with?("> ") && !inside_block?
      return :handle_block_start if block_start?(stripped)
      return :handle_standalone if standalone_block?(stripped)

      nil
    end

    def handle_image(_line, stripped)
      flush_current
      @elements << stripped
    end

    def handle_markdown_blockquote(line, _stripped)
      flush_current
      @current << line
    end

    def handle_block_start(line, _stripped)
      flush_current
      @current << line
    end

    def handle_block_continuation(line, stripped)
      @current << line
      flush_current if block_end?(stripped, @current)
    end

    def handle_standalone(line, _stripped)
      flush_current
      @elements << line.strip
    end

    def blank_line
      flush_current
    end

    def flush_current
      text = @current.strip
      @elements << text unless text.empty?
      @current = +""
    end

    def inside_block?
      inside_pre_block? || inside_code_fence? || inside_blockquote? || inside_html_list? || inside_embed? ||
        inside_table_shortcode?
    end

    def block_start?(stripped)
      stripped.match?(/\A<pre[\s>]/i) ||
        stripped.start_with?("```") ||
        stripped.match?(/\A<blockquote/i) ||
        stripped.match?(/\A<[uo]l[\s>]/i) ||
        stripped.match?(/\A\[table\]/i)
    end

    def standalone_block?(stripped)
      stripped.match?(/\A<embed\s/i)
    end

    def block_end?(stripped, text)
      return stripped.match?(%r{</pre>}i) if inside_pre_block?
      return stripped.start_with?("```") if inside_code_fence?
      return text.match?(%r{</blockquote>}i) if inside_blockquote?
      return stripped.match?(%r{</[uo]l>}i) if inside_html_list?
      return stripped.match?(/\A\[\/table\]/i) if inside_table_shortcode?

      false
    end

    def standalone_image?(line)
      line.match?(/\A#{IMG_TAG_PATTERN}\z/o) || line.match?(/\A!\[[^\]]*\]\([^)]+\)\z/)
    end

    def inside_pre_block?
      @current.match?(/\A<pre[\s>]/i) && !@current.match?(%r{</pre>}i)
    end

    def inside_code_fence?
      @current.start_with?("```") && @current.exclude?("\n```")
    end

    def inside_blockquote?
      @current.match?(/\A<blockquote/i) && !@current.match?(%r{</blockquote>}i)
    end

    def inside_html_list?
      @current.match?(/\A<[uo]l[\s>]/i) && !@current.match?(%r{</[uo]l>}i)
    end

    def inside_embed?
      false
    end

    def inside_markdown_blockquote?
      @current.match?(/\A>\s?/)
    end

    def inside_table_shortcode?
      @current.match?(/\A\[table\]/i) && !@current.match?(/\[\/table\]/i)
    end
  end
end
