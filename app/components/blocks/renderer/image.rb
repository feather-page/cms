# frozen_string_literal: true

module Blocks
  module Renderer
    class Image < Base
      delegate :caption, :image, :image_url, to: :block

      def sources
        [
          { srcset: srcset('webp'), type: 'image/webp' }
        ]
      end

      private

      def figcaption
        return if caption.blank?

        scrubbed_tag(:figcaption, caption)
      end

      def srcset(format)
        # Only webp is used via sources; the format parameter is preserved for
        # future use but currently Routes#image_srcset hard-codes webp.
        if format == 'webp'
          routes.image_srcset(image)
        else
          ::Image::Variants::SIZES.map do |size_name, size|
            "#{routes.image_url(image, :"#{size_name}_#{format}")} #{size}w"
          end.join(', ')
        end
      end
    end
  end
end