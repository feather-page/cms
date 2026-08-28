# frozen_string_literal: true

module Blocks
  module Renderer
    class Header < Base
      erb_template '<h<%= @block.level %>><%= raw(text) %></h<%= @block.level %>>'

      def text
        scrub_html(@block.text)
      end
    end
  end
end