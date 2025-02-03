describe 'User Invitation' do
  describe 'viewing the list of invitations' do
    it 'shows all pending invitations' do
      as_superadmin do |user|
        site = create(:site, users: [user])
        pending_invitation = create(:user_invitation, site:, inviting_user: user)
        accepted_invitation = create(:user_invitation, :accepted, site:, inviting_user: user)

        visit site_users_path(site)

        expect(page).to have_text(pending_invitation.email)
        expect(page).to have_no_text(accepted_invitation.email)
      end
    end
  end

  describe 'iniviting a user' do
    it 'creates a new user' do
      as_superadmin do |user|
        site = create(:site, users: [user])
        invitation = build(:user_invitation)

        visit new_site_invitation_path(site)

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

          visit new_site_invitation_path(site)

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

        visit site_users_path(site)

        within "##{dom_id(invitation)}" do
          click_on 'Resend'
        end

        expect(page).to have_text('Invitation was successfully resent.')
      end
    end
  end

  describe 'revoking an invitation' do
    it 'destroys the invitation' do
      as_superadmin do |user|
        site = create(:site, users: [user])
        invitation = create(:user_invitation, site: site)

        visit site_users_path(site)

        within "##{dom_id(invitation)}" do
          accept_confirm do
            click_on 'Revoke'
          end
        end

        expect(page).to have_text('Invitation was successfully revoked.')
        expect(UserInvitation.where(id: invitation.id).count).to eq(0)
      end
    end
  end

  describe 'accepting an invitation' do
    context 'when invitation was not yet accepted' do
      it 'creates a new user and adds the user to the site' do
        invitation = create(:user_invitation)

        visit edit_invitation_path(id: invitation.accept_invitation_token)

        click_on 'Accept invitation'

        expect(page).to have_text('You have successfully accepted the invitation.')

        expect(User.where(email: invitation.email).count).to eq(1)
        expect(User.find_by(email: invitation.email).sites).to include(invitation.site)
      end
    end

    context 'when invitation was already accepted' do
      it 'does not create a new user' do
        invitation = create(:user_invitation, :accepted)
        visit edit_invitation_path(id: invitation.accept_invitation_token)

        expect(page).to have_text('You have already accepted the invitation.')
      end
    end
  end
end
