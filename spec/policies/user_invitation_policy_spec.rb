describe UserInvitationPolicy do
  subject(:policy) { described_class }

  permissions :new?, :create?, :destroy?, :resend? do
    context 'for a superadmin' do
      it 'returns true' do
        user = build(:user, :superadmin)
        invitation = build(:user_invitation, site: create(:site))
        expect(policy).to permit(user, invitation)
      end
    end

    context 'for a site user' do
      it 'returns true' do
        user = create(:user)
        site = create(:site, users: [user])
        invitation = build(:user_invitation, site:)

        expect(policy).to permit(user, invitation)
      end
    end

    context 'for any other user' do
      it 'returns false' do
        user = build(:user)
        site = create(:site)
        invitation = build(:user_invitation, site:)

        expect(policy).not_to permit(user, invitation)
      end
    end
  end

  permissions :resend? do
    context 'for an already accepted invitation' do
      it 'returns false' do
        invitation = create(:user_invitation, :accepted)

        expect(policy).not_to permit(nil, invitation)
      end
    end

    context 'for a non-accepted invitation' do
      context 'when not signed in' do
        it 'returns true' do
          user = create(:user)
          site = create(:site, users: [user])

          invitation = create(:user_invitation, inviting_user: user, site:)

          expect(policy).to permit(user, invitation)
        end
      end
    end
  end

  permissions :update? do
    context 'when already accepted' do
      it 'returns false' do
        user = create(:user, :superadmin)
        invitation = create(:user_invitation, :accepted)

        expect(policy).not_to permit(user, invitation)
      end
    end

    context 'for a non-accepted invitation' do
      context 'when not signed in' do
        it 'returns true' do
          invitation = create(:user_invitation)

          expect(policy).to permit(nil, invitation)
        end
      end

      context 'when signed in' do
        context 'when the users email matches the invitations email' do
          it 'returns true' do
            invited_user = create(:user)
            invitation = create(:user_invitation, email: invited_user.email)

            expect(policy).to permit(invited_user, invitation)
          end
        end

        context 'when the users email does not match the invitations email' do
          it 'returns false' do
            another_user = create(:user)
            invitation = create(:user_invitation, email: 'another@email.com')

            expect(policy).not_to permit(another_user, invitation)
          end
        end
      end
    end
  end
end
