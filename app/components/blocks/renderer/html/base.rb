module Blocks
  module Renderer
    module Html
      class Base < ViewComponent::Base
        ALLOWED_INLINE_TAGS = %w[b i u a code].freeze
        ALLOWED_ATTRIBUTES = %w[href data-sgid].freeze

        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          ApplicationController.render(self, layout: false)
        end

        private

        def scrubbed_tag(name, content)
          tag(name, resolve_internal_links(scrub_html(content)))
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

        def resolve_internal_links(html)
          return html if Current.site.nil?

          fragment = Loofah.fragment(html)
          fragment.css('a[data-sgid]').each do |link|
            resolve_link(link)
          end

          # rubocop:disable Rails/OutputSafety
          raw(fragment.to_s)
          # rubocop:enable Rails/OutputSafety
        end

        def resolve_link(link)
          target = GlobalID::Locator.locate_signed(link['data-sgid'], for: 'internal_link')

          if link_renderable?(target)
            link['href'] = target.slug
          else
            link.replace(link.text)
            return
          end

          link.delete('data-sgid')
        rescue StandardError
          link.replace(link.text)
        end

        def link_renderable?(target)
          return false unless target
          return false if target.slug.blank?
          return false if target.site_id != Current.site.id
          return false if target.is_a?(Post) && target.draft? && !Current.render_drafts

          true
        end
      end
    end
  end
end
