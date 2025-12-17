module Blocks
  module Renderer
    module Html
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
          ::Image::Variants::SIZES.map do |size_name, size|
            "#{variant_url("#{size_name}_#{format}")} #{size}w"
          end.join(', ')
        end

        def variant_url(variant)
          helpers.url_for(image.file.variant(variant.to_sym))
        end
      end
    end
  end
end
