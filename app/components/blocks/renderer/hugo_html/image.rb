module Blocks
  module Renderer
    module HugoHtml
      class Image
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          return "" if block.image_id.blank?

          image = block.image
          params = ["id=\"#{image.public_id}\""]
          params << "caption=\"#{block.caption}\"" if block.caption.present?
          "{{< image #{params.join(' ')} >}}"
        end
      end
    end
  end
end
