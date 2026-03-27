module Blocks
  module Renderer
    module HugoHtml
      class Book
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          "{{< book id=\"#{block.book_public_id}\" >}}"
        end
      end
    end
  end
end
