describe NavigationItemPolicy do
  subject(:policy) { described_class }

  let!(:navigation_item) { create(:navigation_item) }

  permissions :destroy?, :move_up? do
    context 'for a super admin' do
      let(:user) { build(:user, :superadmin) }

      it 'permits' do
        expect(policy).to permit(user, navigation_item)
      end
    end

    context 'for a user that is part of the site' do
      let(:user) { create(:user, sites: [navigation_item.navigation.site]) }

      it 'permits' do
        expect(policy).to permit(user, navigation_item)
      end
    end

    context 'for a user that is not part of the site' do
      let(:user) { create(:user) }

      it 'denies' do
        expect(policy).not_to permit(user, navigation_item)
      end
    end

    context 'for an anonymous user' do
      let(:user) { nil }

      it 'denies' do
        expect(policy).not_to permit(user, navigation_item)
      end
    end
  end
end
