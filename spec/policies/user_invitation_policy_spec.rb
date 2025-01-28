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
end
