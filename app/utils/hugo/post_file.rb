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
      data = { url: "/images/#{image.public_id}" }

      if image.unsplash?
        data[:unsplash_photographer] = image.unsplash_photographer_name
        data[:unsplash_url] = image.unsplash_photographer_url
      end

      data
    end
  end
end
