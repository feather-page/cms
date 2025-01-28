describe PagePolicy do
  subject(:policy) { described_class }

  let!(:page) { create(:page) }

  permissions :edit?, :add_to_navigation?, :destroy?, :update? do
    context 'for a super admin' do
      let(:user) { build(:user, :superadmin) }

      it 'permits' do
        expect(policy).to permit(user, page)
      end
    end

    context 'for a user that is part of the site' do
      let(:user) { create(:user, sites: [page.site]) }

      it 'permits' do
        expect(policy).to permit(user, page)
      end
    end

    context 'for a user that is not part of the site' do
      let(:user) { create(:user) }

      it 'denies' do
        expect(policy).not_to permit(user, page)
      end
    end

    context 'for an anonymous user' do
      let(:user) { nil }

      it 'denies' do
        expect(policy).not_to permit(user, page)
      end
    end
  end
end
