# frozen_string_literal: true

class BookCoverComponentPreview < Lookbook::Preview
  # @label Finished mit Rating
  def finished_with_rating
    book = Book.where(reading_status: :finished).where.not(rating: nil).first
    render BookCoverComponent.new(book: book) if book
  end

  # @label Want to Read
  def want_to_read
    book = Book.where(reading_status: :want_to_read).first
    if book
      render BookCoverComponent.new(book: book)
    else
      book = Book.first
      render BookCoverComponent.new(book: book) if book
    end
  end

  # @label Currently Reading
  def currently_reading
    book = Book.where(reading_status: :reading).first
    if book
      render BookCoverComponent.new(book: book)
    else
      book = Book.first
      render BookCoverComponent.new(book: book) if book
    end
  end
end
