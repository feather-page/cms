# frozen_string_literal: true

module Hugo
  class PageFile < BaseFile
    def relative_path
      if object.slug == "/"
        "content/_index.html"
      else
        "content/pages/#{object.public_id}.html"
      end
    end

    def content
      [front_matter.to_json, object.hugo_html, special_content].compact.join("\n\n")
    end

    private

    def front_matter
      data = { layout: layout_name }

      data[:url] = object.slug if object.slug.present?
      data[:menu] = "main" if object.slug != "/"
      data[:short] = true if object.title.blank?
      data[:title] = object.title if object.title.present?
      data[:emoji] = object.emoji if object.emoji.present?
      data[:header_image] = header_image_data if object.header_image.present?
      data[:page_type] = object.page_type if object.page_type != "default"
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

    def special_content
      return books_html if object.page_type_books?
      return projects_html if object.page_type_projects?

      nil
    end

    def books_html
      helpers.render(Hugo::BooksListComponent.new(books: object.site.books.ordered), layout: false)
    end

    def projects_html
      helpers.render(
        Hugo::ProjectsListComponent.new(projects: object.site.projects.ordered),
        layout: false,
      )
    end

    def helpers
      ActionController::Base.helpers
    end

    def layout_name
      object.slug == "/" ? "home" : "page"
    end
  end
end
