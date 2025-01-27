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

  describe 'resending an invitation' do
    it 'resends the invitation email' do
      as_superadmin do |user|
        site = create(:site, users: [user])
        invitation = create(:user_invitation, site: site)

        visit site_user_invitations_path(site)

        within "##{dom_id(invitation)}" do
          click_on 'Resend'
        end

        expect(page).to have_text('Invitation was successfully resent.')
      end
    end
  end

  describe 'accepting an invitation' do
    context 'without an existing user' do
      it 'creates a new user and adds the user to the site' do
        as_superadmin do |user|
          site = create(:site, users: [user])
          invitation = create(:user_invitation, site: site)

          visit edit_site_user_invitation_path(site, invitation)

          click_on 'Accept invitation'

          expect(page).to have_text('You have successfully accepted the invitation.')

          expect(User.where(email: invitation.email).count).to eq(1)
          expect(User.find_by(email: invitation.email).sites).to include(site)
        end
      end
    end
  end
end
