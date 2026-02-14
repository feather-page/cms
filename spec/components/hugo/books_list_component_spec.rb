# frozen_string_literal: true

describe Hugo::BooksListComponent, type: :component do
  let(:site) { create(:site) }
  let(:book_with_rating) do
    create(:book, site: site, title: "Clean Code", author: "Robert C. Martin",
                  rating: 5, reading_status: :finished, read_at: Date.new(2024, 6, 15))
  end
  let(:book_without_rating) do
    create(:book, site: site, title: "The Pragmatic Programmer", author: "David Thomas",
                  rating: nil, reading_status: :reading, read_at: nil)
  end

  describe "rendering" do
    it "renders book information" do
      component = described_class.new(books: [book_with_rating], group_by: :year)
      rendered = render_inline(component)

      expect(rendered.text).to include("Clean Code")
      expect(rendered.text).to include("Robert C. Martin")
    end

    it "shows book count in group header" do
      component = described_class.new(books: [book_with_rating], group_by: :year)
      rendered = render_inline(component)

      expect(rendered.css("h2").first.text).to include("(1)")
    end

    it "displays star ratings" do
      component = described_class.new(books: [book_with_rating], group_by: :year)
      rendered = render_inline(component)

      expect(rendered.css(".book-rating").text).to eq("\u2605\u2605\u2605\u2605\u2605")
    end

    it "excludes books without read_at when grouping by year" do
      component = described_class.new(books: [book_with_rating, book_without_rating], group_by: :year)
      rendered = render_inline(component)

      expect(rendered.text).not_to include("The Pragmatic Programmer")
    end

    it "includes all books when grouping by status" do
      component = described_class.new(books: [book_with_rating, book_without_rating], group_by: :status)
      rendered = render_inline(component)

      expect(rendered.text).to include("The Pragmatic Programmer")
    end
  end
end
