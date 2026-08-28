# frozen_string_literal: true

module Blocks
  module Renderer
    class Base < ViewComponent::Base
      ALLOWED_INLINE_TAGS = %w[b i u a code].freeze
      ALLOWED_ATTRIBUTES = %w[href].freeze

      attr_reader :block, :routes

      def initialize(block, routes:)
        @block = block
        @routes = routes
      end

      def to_html
        ApplicationController.render(self, layout: false)
      end

      private

      def scrubbed_tag(name, content)
        tag(name, scrub_html(content))
      end

      def tag(name, content)
        # rubocop:disable Rails/OutputSafety
        raw("<#{name}>#{content}</#{name}>")
        # rubocop:enable Rails/OutputSafety
      end

      def scrub_html(html)
        scrubber = Rails::HTML::PermitScrubber.new
        scrubber.tags = ALLOWED_INLINE_TAGS
        scrubber.attributes = ALLOWED_ATTRIBUTES

        html_fragment = Loofah.fragment(html)
        html_fragment.scrub!(scrubber)

        # rubocop:disable Rails/OutputSafety
        raw(html_fragment.to_s)
        # rubocop:enable Rails/OutputSafety
      end
    end
  end
end