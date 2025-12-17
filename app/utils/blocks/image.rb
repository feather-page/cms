module Blocks
  class Image < Base
    keyword :image_id
    keyword :caption, default: ''

    def self.from_editor_js(hash)
      url = hash['data']['file']['url']
      new(
        id: hash['id'],
        image_id: url.match(%r{/images/([0-9a-zA-Z-]{12,36})})[1],
        caption: hash['data']['caption']
      )
    end

    def editor_js_data
      {
        'file' => { 'url' => image_url }, 'caption' => caption,
        'withBorder' => false, 'stretched' => false, 'withBackground' => false
      }
    end

    def image_url
      return '' unless image

      "/sites/#{image.site.public_id}/images/#{image.public_id}"
    end

    def image
      return @image if defined?(@image)

      @image = ::Image.find(image_id)
    end
  end
end
