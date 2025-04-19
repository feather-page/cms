describe 'Page features' do
  describe 'listing all pages' do
    it 'shows all pages' do
      as_user do |user|
        site = create(:site, users: [user])
        pages = create_list(:page, 2, site:)

        visit site_pages_path(site)

        pages.each do |p|
          expect(page).to have_content(p.title)
        end
      end
    end
  end

  describe 'creating a page' do
    it 'creates a page' do
      as_user do |user|
        site = create(:site, users: [user])

        visit site_pages_path(site)
        click_on 'New Page'

        page_attributes = attributes_for(:page)
        fill_in 'Title', with: page_attributes[:title]
        fill_in 'Slug', with: page_attributes[:slug]
        click_on 'Create Page'

        expect(page).to have_content('Page was successfully created.')
        expect(site.pages).to exist(title: page_attributes[:title])
      end
    end
  end

  describe 'editing a page' do
    it 'updated the page' do
      as_user do |user|
        site = create(:site, users: [user])
        old_page = create(:page, site:)

        visit site_pages_path(site)
        click_on 'Edit'

        page_attributes = attributes_for(:page)
        fill_in 'Title', with: page_attributes[:title]

        click_on 'Update Page'

        expect(page).to have_content('Page was successfully updated.')
        expect(page).to have_content(page_attributes[:title])
        expect(old_page.reload.title).to eq(page_attributes[:title])
      end
    end
  end

  describe 'deleting a page' do
    it 'deletes the page' do
      as_user do |user|
        site = create(:site, users: [user])
        old_page = create(:page, site:)

        visit site_pages_path(site)
        accept_confirm do
          click_on 'Delete'
        end

        expect(page).to have_no_content(old_page.title)
        expect(page).to have_content('Page was successfully deleted.')
      end
    end
  end
end
