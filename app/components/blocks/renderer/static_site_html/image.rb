module Blocks
  module Renderer
    module StaticSiteHtml
      class Image < Html::Image
        def variant_url(variant)
          extension = variant.to_s.split("_").last
          variant_name = variant.to_s.sub(/_#{extension}$/, "")
          "/images/#{image.public_id}/#{variant_name}.#{extension}"
        end
      end
    end
  end
end
