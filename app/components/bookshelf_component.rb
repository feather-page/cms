# frozen_string_literal: true

class BookshelfComponent < ViewComponent::Base
  def initialize(books:, site:)
    @books = books
    @site = site
  end

  def currently_reading
    @currently_reading ||= @books.where(reading_status: :reading).order(created_at: :desc)
  end

  def want_to_read
    @want_to_read ||= @books.where(reading_status: :want_to_read).order(created_at: :desc)
  end

  def finished_by_year
    @finished_by_year ||= @books
      .where(reading_status: :finished)
      .order(read_at: :desc)
      .group_by { |book| book.read_at&.year }
      .sort_by { |year, _| -(year || 0) }
  end

  def empty?
    @books.none?
  end

  def new_book_path
    helpers.new_site_book_path(@site)
  end

  def average_rating(books)
    rated = books.select { |b| b.rating.present? && b.rating > 0 }
    return nil if rated.empty?

    avg = rated.sum(&:rating).to_f / rated.size
    "★" * avg.round + "☆" * (5 - avg.round)
  end
end
