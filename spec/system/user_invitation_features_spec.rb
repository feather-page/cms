describe 'User Invitation' do
  describe 'iniviting a user' do
    it 'creates a new user' do
      as_superadmin do |user|
        site = create(:site, users: [user])
        invitation = build(:user_invitation)

        visit new_site_user_invitation_path(site)

        fill_in 'Email', with: invitation.email
        click_on 'Send invitation'

        expect(page).to have_text('User was successfully invited.')

        expect(UserInvitation.where(email: invitation.email, site:, inviting_user: user).count).to eq(1)
      end
    end

    describe 'when the user already exists' do
      it 'does not create a second user' do
        as_superadmin do |user|
          site = create(:site, users: [user])
          existing_user = create(:user)
          invitation = create(:user_invitation, email: existing_user.email, site: site)

          visit new_site_user_invitation_path(site)

          fill_in 'Email', with: invitation.email
          click_on 'Send invitation'

          expect(page).to have_text('User was successfully invited.')

          expect(UserInvitation.where(email: invitation.email, site:).count).to eq(1)
        end
      end
    end
  end

  describe 'resending an invitation'

  describe 'accepting an invitation'
end
