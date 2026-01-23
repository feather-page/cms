describe BooksController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }

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
  end
end
