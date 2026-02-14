# frozen_string_literal: true

module Blocks
  module Renderer
    module HugoHtml
      def self.render(blocks)
        buffer = ActiveSupport::SafeBuffer.new
        blocks.each do |block|
          buffer.safe_concat(renderer_class(block.type).constantize.new(block).to_html)
        end
        buffer
      end

      def self.renderer_class(type)
        hugo_class = "Blocks::Renderer::HugoHtml::#{type.classify}"
        return hugo_class if Object.const_defined?(hugo_class)

        "Blocks::Renderer::Html::#{type.classify}"
      end
    end
  end
end
