module Hugo
  class DataFile < BaseFile
    attr_reader :site, :type

    def initialize(build_path:, site:, type:)
      super(build_path: build_path)
      @site = site
      @type = type
    end

    def relative_path = "data/#{type}.json"
    def content = JSON.pretty_generate(send(:"#{type}_data"))

    private

    def books_data
      site.books.each_with_object({}) do |book, hash|
        hash[book.public_id] = {
          title: book.title, author: book.author, emoji: book.emoji,
          rating: book.rating, reading_status: book.reading_status,
          read_at: book.read_at&.iso8601,
          cover_url: book_cover_url(book)
        }
      end
    end

    def projects_data
      site.projects.each_with_object({}) do |project, hash|
        hash[project.slug] = {
          title: project.title, emoji: project.emoji, status: project.status,
          status_badge_class: project.status_badge_class, project_type: project.project_type,
          short_description: project.short_description,
          period: project.respond_to?(:display_period) ? project.display_period : nil,
          company: project.company, role: project.role, links: project.links,
          url: "/projects/#{project.slug}/"
        }
      end
    end

    def site_data
      { title: site.title, emoji: site.emoji, language_code: site.language_code,
        domain: site.domain, copyright: site.copyright }
    end

    def book_cover_url(book)
      return nil unless book.cover_image&.file&.attached?
      Hugo::ImageVariant.new(image: book.cover_image, variant_name: :mobile_x1_webp).public_path
    end
  end
end
