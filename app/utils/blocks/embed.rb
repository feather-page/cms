module Blocks
  class Embed < Base
    keyword :service
    keyword :source
    keyword :embed
    keyword :width, default: nil
    keyword :height, default: nil
    keyword :caption, default: ""

    def self.from_editor_js(hash)
      new(
        id: hash['id'],
        service: hash['data']['service'],
        source: hash['data']['source'],
        embed: hash['data']['embed'],
        width: hash['data']['width'],
        height: hash['data']['height'],
        caption: hash['data']['caption'] || ""
      )
    end

    def editor_js_data
      {
        'service' => service,
        'source' => source,
        'embed' => embed,
        'width' => width,
        'height' => height,
        'caption' => caption
      }
    end
  end
end
