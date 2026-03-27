module Blocks
  module Renderer
    module HugoHtml
      def self.render(blocks)
        rendered_blocks = blocks.map do |block|
          renderer_class(block.type).constantize.new(block).to_html
        end

        # rubocop:disable Rails/OutputSafety
        # In this instance we really do return HTML
        rendered_blocks.join("\n\n").html_safe
        # rubocop:enable Rails/OutputSafety
      end

      def self.renderer_class(type)
        hugo_renderer_class_name = "Blocks::Renderer::HugoHtml::#{type.classify}"
        return hugo_renderer_class_name if Object.const_defined?(hugo_renderer_class_name)

        "Blocks::Renderer::Html::#{type.classify}"
      end
    end
  end
end
