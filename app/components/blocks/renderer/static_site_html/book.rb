module Blocks
  module Renderer
    module StaticSiteHtml
      class Book < Html::Book
        private

        def cover_image_tag
          helpers.content_tag(
            :img,
            nil,
            src: static_cover_url,
            alt: book.title,
            class: 'book-cover'
          )
        end

        def emoji_span
          helpers.content_tag(:span, book.emoji, class: 'book-emoji')
        end

        def static_cover_url
          "/images/#{book.cover_image.public_id}/mobile_x1.webp"
        end
      end
    end
  end
end
