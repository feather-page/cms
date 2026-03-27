module Blocks
  module Renderer
    module HugoHtml
      class Code
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          "{{< highlight #{block.language} >}}\n#{block.code}\n{{< /highlight >}}"
        end
      end
    end
  end
end
