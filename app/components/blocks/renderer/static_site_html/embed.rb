module Blocks
  module Renderer
    module StaticSiteHtml
      class Embed < Html::Embed
        def embed_url
          block.embed.gsub("youtube.com/embed/", "youtube-nocookie.com/embed/")
        end
      end
    end
  end
end
