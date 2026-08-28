# frozen_string_literal: true

module Blocks
  module Renderer
    class List < Base
      def call
        list(@block.items)
      end

      private

      def list(items)
        return '' unless items.any?

        list_content = items.map { |i| item_html(i) }.join

        tag(@block.style, list_content)
      end

      def item_html(item)
        child_lists = list(item['items'])
        "<li>#{scrub_html(item['content'])}#{child_lists}</li>"
      end
    end
  end
end