module Blocks
  module Renderer
    module Html
      class Book < Base
        delegate :book, :book_public_id, to: :block

        def cover_or_emoji
          return emoji_span if book&.emoji.present? && !cover_attached?
          return cover_image_tag if cover_attached?

          nil
        end

        private

        def cover_image_tag
          helpers.image_tag(
            book.cover_image.file.variant(:mobile_x1_webp),
            style: 'max-height: 40px;',
            class: 'rounded'
          )
        end

        def emoji_span
          helpers.content_tag(:span, book.emoji, style: 'font-size: 1.5rem;')
        end

        def cover_attached?
          return false unless book&.cover_image

          book.cover_image.file.attached?
        end
      end
    end
  end
end
