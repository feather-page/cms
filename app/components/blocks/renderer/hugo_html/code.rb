# frozen_string_literal: true

module Blocks
  module Renderer
    module HugoHtml
      class Code < Html::Code
        # Uses standard HTML pre/code blocks (Hugo renders raw HTML in .html content files)
      end
    end
  end
end
