describe 'Social links' do
  describe 'adding a social link' do
    it 'adds a social link to a site' do
      as_user do |user|
        site = create(:site, users: [user])
        visit edit_site_path(site)

        click_on 'Add link'

        click_on 'Instagram'

        fill_in 'Name', with: 'Instagram'
        fill_in 'URL', with: 'https://instagram.com/example'

        click_on 'Create link'
        expect(page).to have_text('Social media link was successfully created.')

        expect(site.social_media_links.last.url).to eq('https://instagram.com/example')
      end
    end
  end

  describe 'deleting a social link' do
    it 'deletes a social link from a site' do
      as_user do |user|
        site = create(:site, users: [user])
        social_media_link = create(:social_media_link, site: site)

        visit edit_site_path(site)

        within("##{dom_id(social_media_link)}") do
          accept_confirm do
            click_on 'Delete'
          end
        end

        expect(page).to have_text('Social media link was successfully deleted.')
        expect(site.social_media_links).to be_empty
      end
    end
  end
end
