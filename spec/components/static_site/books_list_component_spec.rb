describe StaticSite::BooksListComponent, type: :component do
  let(:site) { create(:site) }
  let(:book_with_rating) do
    create(:book, site: site, title: "Clean Code", author: "Robert C. Martin",
           rating: 5, reading_status: :finished, read_at: Date.new(2024, 6, 15))
  end
  let(:book_without_rating) do
    create(:book, site: site, title: "The Pragmatic Programmer", author: "David Thomas",
           rating: nil, reading_status: :reading, read_at: nil)
  end
  let(:books) { [book_with_rating, book_without_rating] }

  describe "#initialize" do
    it "accepts books and group_by parameter" do
      component = described_class.new(books: books, group_by: :year)
      expect(component).to be_a(described_class)
    end

    it "defaults to grouping by year" do
      component = described_class.new(books: books)
      expect(component).to be_a(described_class)
    end
  end

  describe "private methods" do
    describe "#group_books" do
      context "when grouping by year" do
        it "groups books by their read_at year" do
          component = described_class.new(books: books, group_by: :year)
          rendered = render_inline(component)
          expect(rendered.css("h2").first.text).to include("2024")
        end

        it "excludes books without read_at date" do
          component = described_class.new(books: books, group_by: :year)
          rendered = render_inline(component)
          expect(rendered.text).not_to include("The Pragmatic Programmer")
        end
      end

      context "when grouping by status" do
        it "groups books by reading status" do
          component = described_class.new(books: books, group_by: :status)
          rendered = render_inline(component)
          expect(rendered.css("h2").map(&:text).join).to include("Finished")
        end

        it "includes all books regardless of read_at date" do
          component = described_class.new(books: books, group_by: :status)
          rendered = render_inline(component)
          expect(rendered.text).to include("The Pragmatic Programmer")
        end
      end
    end

    describe "#group_title" do
      it "returns human-readable status titles" do
        component = described_class.new(books: books, group_by: :status)
        rendered = render_inline(component)
        expect(rendered.text).to include("Currently Reading")
      end
    end

    describe "#rating_stars" do
      it "displays filled and empty stars for rated books" do
        component = described_class.new(books: [book_with_rating], group_by: :year)
        rendered = render_inline(component)
        expect(rendered.css(".book-rating").text).to eq("★★★★★")
      end

      it "does not display stars for unrated books" do
        component = described_class.new(books: [book_without_rating], group_by: :status)
        rendered = render_inline(component)
        expect(rendered.css(".book-rating")).to be_empty
      end
    end

    describe "#cover_path" do
      context "when book has a cover image" do
        let(:book_with_cover) do
          book = create(:book, site: site, title: "With Cover", author: "Author",
                        reading_status: :finished, read_at: Date.new(2024, 1, 1))
          image = create(:image, imageable: book)
          book.reload
          book
        end

        it "returns the static site image path" do
          component = described_class.new(books: [book_with_cover], group_by: :year)
          rendered = render_inline(component)
          expect(rendered.css(".book-cover").first["src"]).to include("/images/")
          expect(rendered.css(".book-cover").first["src"]).to include("/mobile_x1.webp")
        end
      end

      context "when book has no cover image" do
        it "does not render an img tag" do
          component = described_class.new(books: [book_with_rating], group_by: :year)
          rendered = render_inline(component)
          expect(rendered.css(".book-cover")).to be_empty
        end
      end
    end

    describe "#review_url" do
      context "when book has a review post with title" do
        let(:book_with_review) do
          book = create(:book, site: site, title: "Reviewed", author: "Author",
                        reading_status: :finished, read_at: Date.new(2024, 1, 1))
          post = create(:post, site: site, title: "My Review")
          book.update!(post: post)
          book
        end

        it "renders the title as a link" do
          component = described_class.new(books: [book_with_review], group_by: :year)
          rendered = render_inline(component)
          expect(rendered.css("a.book-title")).to be_present
          expect(rendered.css("a.book-title").first["href"]).to include("/posts/")
        end
      end

      context "when book has no review" do
        it "renders the title as a span" do
          component = described_class.new(books: [book_with_rating], group_by: :year)
          rendered = render_inline(component)
          expect(rendered.css("span.book-title")).to be_present
          expect(rendered.css("a.book-title")).to be_empty
        end
      end
    end
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

    it "displays emoji when present" do
      book_with_rating.update!(emoji: "📚")
      component = described_class.new(books: [book_with_rating], group_by: :year)
      rendered = render_inline(component)

      expect(rendered.css(".book-emoji").text).to eq("📚")
    end
  end
end
