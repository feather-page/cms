describe 'User Invitation' do
  describe 'iniviting a user' do
    it 'creates a new user' do
      as_superadmin do |user|
        site = create(:site, users: [user])
        invitation = build(:site_user_invitation)

        pp new_site_site_user_invitations_path(site)
        visit new_site_site_user_invitations_path(site)

        fill_in 'Email', with: invitation.email
        click_on 'Send an invitation'

        expect(page).to have_text('User was successfully invited.')

        expect(SiteUserInvitation.find_by_email(email: invitation.email, site:, user:)).to be_present
      end
    end
  end

  describe 'resending an invitation'

  describe 'accepting an invitation'
end
