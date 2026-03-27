module Blocks
  module Renderer
    module HugoHtml
      class Embed
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          case block.service
          when "youtube"
            video_id = extract_youtube_id(block.source)
            "{{< youtube #{video_id} >}}"
          when "vimeo"
            video_id = extract_vimeo_id(block.source)
            "{{< vimeo #{video_id} >}}"
          else
            params = ["url=\"#{block.embed}\""]
            params << "caption=\"#{block.caption}\"" if block.caption.present?
            "{{< embed #{params.join(' ')} >}}"
          end
        end

        private

        def extract_youtube_id(url)
          return "" if url.blank?

          if url.include?("watch?v=")
            url.match(/[?&]v=([^&]+)/)&.then { |m| m[1] } || ""
          elsif url.include?("youtu.be/")
            url.match(%r{youtu\.be/([^?&/]+)})&.then { |m| m[1] } || ""
          elsif url.include?("/embed/")
            url.match(%r{/embed/([^?&/]+)})&.then { |m| m[1] } || ""
          else
            ""
          end
        end

        def extract_vimeo_id(url)
          return "" if url.blank?

          url.match(%r{/(\d+)})&.then { |m| m[1] } || ""
        end
      end
    end
  end
end
