describe 'Basic Site features' do
  describe 'listing all sites' do
    context 'for a user' do
      it 'displays own sites' do
        as_user do |user|
          allowed_site = create(:site, users: [user])
          disallowed_site = create(:site)

          visit root_path

          expect(page).to have_content(allowed_site.title)
          expect(page).to have_no_content(disallowed_site.title)
        end
      end
    end

    context 'for a superadmin' do
      it 'displays all site' do
        as_superadmin do |_admin|
          site = create(:site)

          visit root_path

          expect(page).to have_content(site.title)
        end
      end
    end
  end

  describe 'creating a site as registed user' do
    context 'when user provides a title' do
      it 'creates a new site' do
        as_user do
          visit new_site_path

          fill_in 'Title', with: 'My Site'
          fill_in 'Domain', with: 'rocu.de'
          select 'fr', from: 'Language'

          click_on 'Create Site'

          expect(page).to have_content('Site was successfully created.')
          expect(page).to have_content('My Site')
        end
      end
    end

    context 'when user provides no title' do
      it 'shows an error' do
        as_user do
          visit new_site_path

          click_on 'Create Site'

          expect(page).to have_content("can't be blank")
        end
      end
    end
  end

  describe 'editing a site' do
    context 'when user is owner' do
      it 'updates the site' do
        as_user do |user|
          site = create(:site, users: [user])

          visit edit_site_path(site)

          fill_in 'Title', with: 'Other Title'
          fill_in 'Domain', with: 'rocu.de'
          select 'fr', from: 'Language'
          fill_in 'Emoji', with: '🥋'
          fill_in 'Copyright', with: 'Foobar Copyright 2048'

          click_on 'Update Site'

          expect(page).to have_content('Site was successfully updated.')
          expect(page).to have_content('Other Title')
          site.reload
          expect(site.emoji).to eq('🥋')
          expect(site.copyright).to eq('Foobar Copyright 2048')
        end
      end
    end
  end
end
