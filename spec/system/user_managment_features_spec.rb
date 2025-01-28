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
        user = create(:user, sites: [site])

        visit site_users_path(site)
        click_link 'Remove'

        expect(page).to have_no_text(user.email)
      end
    end
  end
end
