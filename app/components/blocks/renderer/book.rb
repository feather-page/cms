# frozen_string_literal: true

module Blocks
  module Renderer
    class Book < Base
      delegate :book, :book_public_id, to: :block

      def cover_or_emoji
        return emoji_span if book&.emoji.present? && !cover_attached?
        return cover_image_tag if cover_attached?

        nil
      end

      private

      def cover_image_tag
        helpers.content_tag(
          :img,
          nil,
          src: routes.image_url(book.cover_image, :mobile_x1_webp),
          alt: book.title,
          class: 'book-cover'
        )
      end

      def emoji_span
        helpers.content_tag(:span, book.emoji, class: 'book-emoji')
      end

      def cover_attached?
        return false unless book&.cover_image

        book.cover_image.file.attached?
      end
    end
  end
end