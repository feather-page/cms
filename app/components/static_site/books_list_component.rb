module StaticSite
  class BooksListComponent < ViewComponent::Base
    READING_STATUS_TITLES = {
      "want_to_read" => "Want to Read",
      "reading" => "Currently Reading",
      "finished" => "Finished"
    }.freeze

    def initialize(books:, routes:, group_by: :year)
      @books = group_books(books, group_by)
      @group_by = group_by
      @routes = routes
    end

    private

    attr_reader :group_by, :routes

    def group_books(books, group_by)
      case group_by
      when :year
        books.select { |b| b.read_at.present? }.group_by(&:year)
      when :status
        books.group_by(&:reading_status)
      else
        books.group_by(&:year)
      end
    end

    def group_title(key)
      if group_by == :status
        READING_STATUS_TITLES[key] || key.to_s.titleize
      else
        key.to_s
      end
    end

    def cover_path(book)
      return nil unless book.cover_image&.file&.attached?

      routes.image_url(book.cover_image, :mobile_x1_webp)
    end

    def review_url(book)
      return nil unless book.post.present? && book.post.title.present?

      routes.post_url(book.post)
    end

    def rating_stars(rating)
      return nil if rating.blank?

      filled = "\u2605" * rating
      empty = "\u2606" * (5 - rating)
      filled + empty
    end
  end
end
