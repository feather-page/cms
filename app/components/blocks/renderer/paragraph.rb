# frozen_string_literal: true

module Blocks
  module Renderer
    class Paragraph < Base
      erb_template '<p><%= raw(text) %></p>'

      def text
        scrub_html(@block.text)
      end
    end
  end
end