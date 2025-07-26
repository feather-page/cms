describe BookPolicy do
  subject(:policy) { described_class }

  let!(:book) { create(:book) }

  permissions :new?, :create?, :destroy?, :edit?, :update? do
    context 'for a super admin' do
      let(:user) { build(:user, :superadmin) }

      it 'permits' do
        expect(policy).to permit(user, book)
      end
    end

    context 'for a user that is part of the site' do
      let(:user) { create(:user, sites: [book.site]) }

      it 'permits' do
        expect(policy).to permit(user, book)
      end
    end

    context 'for a user that is not part of the site' do
      let(:user) { create(:user) }

      it 'denies' do
        expect(policy).not_to permit(user, book)
      end
    end

    context 'for an anonymous user' do
      let(:user) { nil }

      it 'denies' do
        expect(policy).not_to permit(user, book)
      end
    end
  end
end
