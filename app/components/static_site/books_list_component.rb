module StaticSite
  class BooksListComponent < ViewComponent::Base
    READING_STATUS_TITLES = {
      "want_to_read" => "Want to Read",
      "reading" => "Currently Reading",
      "finished" => "Finished"
    }.freeze

    def initialize(books:, group_by: :year)
      @books = group_books(books, group_by)
      @group_by = group_by
    end

    private

    attr_reader :group_by

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

      "/images/#{book.cover_image.public_id}/mobile_x1.webp"
    end

    def review_url(book)
      return nil unless book.post.present? && book.post.title.present?

      "/posts/#{book.post.public_id.downcase}/"
    end

    def rating_stars(rating)
      return nil if rating.blank?

      filled = "\u2605" * rating
      empty = "\u2606" * (5 - rating)
      filled + empty
    end
  end
end
