module Hugo
  class BooksListComponent < ViewComponent::Base
    def initialize(books:)
      @books = books.group_by(&:year)
    end
  end
end
