# frozen_string_literal: true

module Hugo
  class PostFile < BaseFile
    def relative_path
      "content/posts/#{object.public_id}.html"
    end

    def content
      [front_matter.to_json, object.hugo_html].join("\n\n")
    end

    private

    def front_matter
      data = { date: object.publish_at.strftime("%Y-%m-%d") }

      data[:url] = object.slug if object.slug.present?
      data[:short] = true if object.title.blank?
      data[:title] = object.title if object.title.present?
      data[:emoji] = object.emoji if object.emoji.present?
      data[:header_image] = header_image_data if object.header_image.present?
      data[:book] = book_data if object.book.present?
      data
    end

    def book_data
      book = object.book
      data = { title: book.title, author: book.author }
      data[:emoji] = book.emoji if book.emoji.present?
      data[:rating] = book.rating if book.rating.present?
      data[:rating_stars] = rating_stars(book.rating) if book.rating.present?
      data[:cover] = book_cover_url(book) if book.cover_image&.file&.attached?
      data
    end

    def book_cover_url(book)
      return unless book.cover_image&.file&.attached?

      "/images/#{book.cover_image.public_id}/mobile_x1.webp"
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
        srcset: header_image_srcset(base_path),
      }
    end

    def header_image_srcset(base_path)
      Image::Variants::SIZES.map do |name, width|
        "#{base_path}/#{name}.webp #{width}w"
      end.join(", ")
    end

    def rating_stars(rating)
      return nil if rating.blank?

      ("\u2605" * rating) + ("\u2606" * (5 - rating))
    end
  end
end
