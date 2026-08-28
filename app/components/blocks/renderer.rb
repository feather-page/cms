# frozen_string_literal: true

require "json"

module Blocks
  module Renderer
    def self.render(blocks, routes:)
      rendered_blocks = blocks.map do |block|
        renderer_class = "Blocks::Renderer::#{block.type.classify}".constantize
        renderer_class.new(block, routes:).to_html
      end

      # rubocop:disable Rails/OutputSafety
      # In this instance we really do return HTML
      rendered_blocks.join.html_safe
      # rubocop:enable Rails/OutputSafety
    end
  end
end