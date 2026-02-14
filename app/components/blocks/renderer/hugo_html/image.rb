# frozen_string_literal: true

module Blocks
  module Renderer
    module HugoHtml
      class Image < Html::Image
        def variant_url(variant)
          Hugo::ImageVariant.new(image, variant).public_path
        end
      end
    end
  end
end
