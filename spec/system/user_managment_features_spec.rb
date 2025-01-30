describe 'User Managment' do
  describe 'viewing the list of users' do
    it 'shows all the site users' do
      as_superadmin do |admin|
        site = create(:site, users: [admin])
        users = create_list(:user, 3, sites: [site])

        visit site_users_path(site)

        expect(page).to have_text(admin.email)
        users.each do |user|
          expect(page).to have_text(user.email)
        end
      end
    end
  end

  describe 'removing a user from the site' do
    it 'removes the user from the site' do
      as_superadmin do |admin|
        site = create(:site, users: [admin])
        site_user = create(:site_user, site:)

        visit site_users_path(site)

        within "##{dom_id(site_user)}" do
          accept_confirm do
            click_on 'Remove'
          end
        end

        expect(page).to have_no_text(site_user.user.email)
        expect(site.users).not_to include(site_user.user)
      end
    end
  end
end
