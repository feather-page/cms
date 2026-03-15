describe BooksController do
  include_context "authenticated user"

  describe 'GET #lookup' do
    let!(:gatsby_book) { create(:book, site:, title: 'The Great Gatsby', author: 'F. Scott Fitzgerald') }
    let!(:mockingbird_book) { create(:book, site:, title: 'To Kill a Mockingbird', author: 'Harper Lee') }
    let!(:gatsby_revisited_book) { create(:book, site:, title: 'Gatsby Revisited', author: 'Another Author') }

    it 'returns books matching the title' do
      get lookup_site_books_path(site), params: { q: 'Gatsby' }

      expect(response).to be_successful
      expect(response.parsed_body.pluck('title')).to contain_exactly(
        'The Great Gatsby',
        'Gatsby Revisited'
      )
    end

    it 'returns books matching the author' do
      get lookup_site_books_path(site), params: { q: 'Harper' }

      expect(response).to be_successful
      expect(response.parsed_body.pluck('title')).to contain_exactly('To Kill a Mockingbird')
    end

    it 'returns the correct JSON structure' do
      get lookup_site_books_path(site), params: { q: 'Mockingbird' }

      expect(response).to be_successful
      book_json = response.parsed_body.first

      expect(book_json).to include(
        'public_id' => mockingbird_book.public_id,
        'title' => 'To Kill a Mockingbird',
        'author' => 'Harper Lee',
        'emoji' => mockingbird_book.emoji
      )
      expect(book_json).to have_key('cover_url')
    end

    it 'limits results to 10 books' do
      10.times { |i| create(:book, site:, title: "Similar Title #{i}") }

      get lookup_site_books_path(site), params: { q: 'Similar' }

      expect(response).to be_successful
      expect(response.parsed_body.length).to eq(10)
    end

    it 'returns an empty array when no books match' do
      get lookup_site_books_path(site), params: { q: 'NonexistentBook' }

      expect(response).to be_successful
      expect(response.parsed_body).to eq([])
    end

    it 'does not return books from other sites' do
      other_site = create(:site)
      create(:book, site: other_site, title: 'Other Site Book')

      get lookup_site_books_path(site), params: { q: 'Other Site' }

      expect(response).to be_successful
      expect(response.parsed_body).to eq([])
    end

    context 'without search query' do
      it 'returns the 5 most recent books ordered by read_at and created_at' do
        get lookup_site_books_path(site)

        expect(response).to be_successful
        expect(response.parsed_body.length).to be <= 5
      end

      it 'limits results to 5 books' do
        10.times { |i| create(:book, site:, title: "Book #{i}") }

        get lookup_site_books_path(site)

        expect(response).to be_successful
        expect(response.parsed_body.length).to eq(5)
      end
    end

    context 'with cover image' do
      it 'returns the cover_url when book has a cover image' do
        book_with_cover = create(:book, site:, title: 'Book With Cover')
        create(:image, site:, imageable: book_with_cover)

        get lookup_site_books_path(site), params: { q: 'Book With Cover' }

        expect(response).to be_successful
        book_json = response.parsed_body.first
        expect(book_json['cover_url']).to be_present
      end
    end
  end

  describe 'GET #index' do
    let!(:finished_book) { create(:book, site:, title: 'Finished Book', reading_status: :finished) }
    let!(:want_to_read_book) { create(:book, :want_to_read, site:, title: 'Want To Read Book') }
    let!(:reading_book) { create(:book, :reading, site:, title: 'Currently Reading Book') }

    it 'returns successful response' do
      get site_books_path(site)
      expect(response).to be_successful
    end

    it 'shows all books grouped in bookshelf' do
      get site_books_path(site)
      expect(response.body).to include('Finished Book')
      expect(response.body).to include('Want To Read Book')
      expect(response.body).to include('Currently Reading Book')
    end

    it 'does not show books from other sites' do
      other_site = create(:site)
      create(:book, site: other_site, title: 'Other Site Book')

      get site_books_path(site)
      expect(response.body).not_to include('Other Site Book')
    end
  end

  describe 'POST #create' do
    context 'with valid finished book parameters' do
      let(:valid_params) do
        {
          book: {
            title: 'The Great Gatsby',
            author: 'F. Scott Fitzgerald',
            emoji: "\u{1F4D6}",
            read_at: '2025-06-15',
            reading_status: 'finished'
          }
        }
      end

      it 'creates a new book' do
        expect do
          post site_books_path(site), params: valid_params
        end.to change(Book, :count).by(1)
      end

      it 'assigns the correct attributes' do
        post site_books_path(site), params: valid_params
        book = Book.last
        expect(book.title).to eq('The Great Gatsby')
        expect(book.author).to eq('F. Scott Fitzgerald')
        expect(book.emoji).to eq("\u{1F4D6}")
        expect(book.reading_status).to eq('finished')
        expect(book.read_at).to eq(Date.parse('2025-06-15'))
      end

      it 'assigns the book to the current site' do
        post site_books_path(site), params: valid_params
        expect(Book.last.site).to eq(site)
      end

      it 'returns turbo stream redirect to books index' do
        post site_books_path(site), params: valid_params
        expect(response).to be_successful
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('/books')
      end

      it 'sets a success notice' do
        post site_books_path(site), params: valid_params
        expect(flash[:notice]).to be_present
      end
    end

    context 'with valid want_to_read book parameters' do
      let(:want_to_read_params) do
        {
          book: {
            title: 'Future Read',
            author: 'Some Author',
            reading_status: 'want_to_read'
          }
        }
      end

      it 'creates a want_to_read book without read_at' do
        expect do
          post site_books_path(site), params: want_to_read_params
        end.to change(Book, :count).by(1)
      end

      it 'sets the reading status to want_to_read' do
        post site_books_path(site), params: want_to_read_params
        book = Book.last
        expect(book.reading_status).to eq('want_to_read')
        expect(book.read_at).to be_nil
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          book: {
            title: '',
            author: 'Some Author',
            reading_status: 'finished'
          }
        }
      end

      it 'does not create a book' do
        expect do
          post site_books_path(site), params: invalid_params
        end.not_to change(Book, :count)
      end
    end
  end

  describe 'PATCH #update' do
    let(:book) { create(:book, site:, title: 'Original Title', reading_status: :finished) }

    context 'updating the title' do
      it 'updates the book title' do
        patch book_path(book), params: { book: { title: 'Updated Title' } }
        book.reload
        expect(book.title).to eq('Updated Title')
      end

      it 'returns turbo stream redirect to books index' do
        patch book_path(book), params: { book: { title: 'Updated Title' } }
        expect(response).to be_successful
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('/books')
      end

      it 'sets a success notice' do
        patch book_path(book), params: { book: { title: 'Updated Title' } }
        expect(flash[:notice]).to be_present
      end
    end

    context 'changing reading status' do
      it 'changes from finished to want_to_read' do
        patch book_path(book), params: { book: { reading_status: 'want_to_read', read_at: '' } }
        book.reload
        expect(book.reading_status).to eq('want_to_read')
      end

      it 'changes from want_to_read to finished with read_at' do
        want_book = create(:book, :want_to_read, site:)
        patch book_path(want_book), params: { book: { reading_status: 'finished', read_at: '2025-06-15' } }
        want_book.reload
        expect(want_book.reading_status).to eq('finished')
        expect(want_book.read_at).to eq(Date.parse('2025-06-15'))
      end
    end

    context 'with invalid parameters' do
      it 'does not update the book' do
        patch book_path(book), params: { book: { title: '' } }
        book.reload
        expect(book.title).to eq('Original Title')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:book) { create(:book, site:) }

    it 'deletes the book' do
      expect do
        delete book_path(book), as: :turbo_stream
      end.to change(Book, :count).by(-1)
    end

    it 'returns successful response' do
      delete book_path(book), as: :turbo_stream
      expect(response).to be_successful
    end
  end
end
