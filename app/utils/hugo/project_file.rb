# frozen_string_literal: true

module Hugo
  class ProjectFile < BaseFile
    def relative_path
      "content/projects/#{object.slug}.html"
    end

    def content
      [front_matter.to_json, object.hugo_html].join("\n\n")
    end

    private

    def front_matter
      data = {
        title: object.title,
        url: "/projects/#{object.slug}/",
        layout: "project",
        status: object.status,
        status_badge_class: object.status_badge_class,
      }

      data[:emoji] = object.emoji if object.emoji.present?
      data[:company] = object.company if object.company.present?
      data[:role] = object.role if object.role.present?
      data[:period] = object.display_period
      data[:short_description] = object.short_description
      data[:started_at] = object.started_at.to_s
      data[:project_type] = object.project_type
      data[:links] = object.links if object.links.present?
      data[:header_image] = header_image_data if object.header_image.present?
      data
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
  end
end
