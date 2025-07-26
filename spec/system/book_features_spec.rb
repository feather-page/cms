describe 'Book features' do
  describe 'creating a new book' do
    it 'creates a new bok' do
      as_user do |user|
        site = create(:site, users: [user])

        visit new_site_book_path(site)

        fill_in 'Title', with: 'My Book'
        fill_in 'Author', with: 'Foo Bar'
        fill_in 'Emoji', with: '📕'

        fill_in 'Read at', with: '2020-01-01'

        expect do
          click_on 'Create Book'
        end.to change { site.books.count }.by(1)

        created_book = site.books.last
        expect(created_book.title).to eq('My Book')
        expect(created_book.author).to eq('Foo Bar')
        expect(created_book.read_at.to_date).to eq(Date.new(2020, 1, 1))
      end
    end
  end

  describe 'editing a book' do
    it 'edits a book' do
      as_user do |user|
        site = create(:site, users: [user])
        book = create(:book, site:)

        visit edit_book_path(book)

        fill_in 'Title', with: 'New title'

        click_on 'Update Book'

        expect(book.reload.title).to eq('New title')
      end
    end
  end

  describe 'deleting a book' do
    it 'deletes a book' do
      as_user do |user|
        site = create(:site, users: [user])
        book = create(:book, site:)

        visit site_books_path(site)

        accept_confirm do
          click_link('Delete')
        end

        expect(Book.find_by(id: book.id)).to be_nil
      end
    end
  end
end
