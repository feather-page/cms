# frozen_string_literal: true

class BookshelfComponentPreview < Lookbook::Preview
  # @label Mit Büchern
  def with_books
    site = Site.first
    render BookshelfComponent.new(books: site.books, site: site) if site
  end

  # @label Leer
  def empty
    site = Site.first
    render BookshelfComponent.new(books: site.books.none, site: site) if site
  end
end
