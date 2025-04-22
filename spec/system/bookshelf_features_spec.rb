describe 'Bookshelf features' do
  describe 'listing all bookshelves' do
    it 'displays all bookshelves' do
      as_site_user do |_user, site|
        bookshelf = create(:bookshelf, site: site)

        visit site_bookshelves_path(site)

        expect(page).to have_content(bookshelf.name)
      end
    end
  end

  describe 'creating a new bookshelf' do
    it 'creates a new bookshelf' do
      bookshelf = attributes_for(:bookshelf)

      as_site_user do |_user, site|
        visit site_bookshelves_path(site)

        click_on 'New Bookshelf'

        fill_in 'Name', with: bookshelf[:name]

        expect do
          click_on 'Create Bookshelf'
        end.to change(Bookshelf, :count).by(1)

        expect(page).to have_content(bookshelf[:name])
      end
    end
  end
end
