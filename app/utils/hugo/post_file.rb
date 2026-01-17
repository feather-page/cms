module Hugo
  class PostFile < BaseFile
    def relative_path
      "content/posts/#{object.public_id}.html"
    end

    def content
      [front_matter.to_json, object.hugo_html].join("\n\n")
    end

    private

    def front_matter # rubocop:disable Metrics/AbcSize
      front_matter = { date: object.publish_at.strftime('%Y-%m-%d') }

      front_matter[:url] = object.slug if object.slug.present?
      front_matter[:short] = true if object.title.blank?
      front_matter[:title] = object.title if object.title.present?
      front_matter[:emoji] = object.emoji if object.emoji.present?
      front_matter[:header_image] = header_image_data if object.header_image.present?
      front_matter
    end

    def header_image_data
      image = object.header_image
      data = header_image_urls(image)

      if image.unsplash?
        data[:unsplash_photographer] = image.unsplash_photographer_name
        data[:unsplash_url] = image.unsplash_photographer_url
      end

      data
    end

    def header_image_urls(image)
      base_path = "/images/#{image.public_id}"
      {
        url: "#{base_path}/desktop_x1.webp",
        srcset: header_image_srcset(base_path)
      }
    end

    def header_image_srcset(base_path)
      Image::Variants::SIZES.map do |name, width|
        "#{base_path}/#{name}.webp #{width}w"
      end.join(", ")
    end
  end
end
