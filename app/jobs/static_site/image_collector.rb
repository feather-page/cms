module StaticSite
  class ImageCollector
    def initialize(site)
      @site = site
    end

    def to_a
      (content_images + header_images + book_covers).compact.uniq
    end

    private

    attr_reader :site

    def content_images
      site.images.assigned.to_a
    end

    def header_images
      post_headers + page_headers
    end

    def post_headers
      site.posts.includes(:header_image).where.not(header_image: nil).map(&:header_image)
    end

    def page_headers
      site.pages.includes(:header_image).where.not(header_image: nil).map(&:header_image)
    end

    def book_covers
      site.books.includes(:cover_image).where.not(cover_image: nil).map(&:cover_image)
    end
  end
end
