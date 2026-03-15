# frozen_string_literal: true

class BookCoverComponent < ViewComponent::Base
  def initialize(book:)
    @book = book
  end

  def cover_image?
    @book.cover_image&.file&.attached?
  end

  def show_rating?
    @book.reading_status_finished? && @book.rating.present? && @book.rating > 0
  end

  def star_rating
    "★" * @book.rating + "☆" * (5 - @book.rating)
  end

  def edit_path
    helpers.edit_book_path(@book)
  end

  def emoji_or_fallback
    @book.emoji.presence || "📖"
  end
end
