module Blocks
  module Renderer
    module StaticSiteHtml
      class Code < Html::Code
        # Use standard HTML pre/code blocks instead of Hugo shortcodes
      end
    end
  end
end
