describe Sites::CreateSite do
  subject(:outcome) { described_class.run(title:, current_user:) }

  let(:title) { 'My Site' }
  let(:current_user) { create(:user) }

  describe '#execute' do
    context 'when site is valid' do
      let(:created_site) { outcome.result }

      it 'creates a site' do
        expect(created_site).to be_persisted
      end

      it 'adds the site to the current user' do
        expect(created_site.users).to include(current_user)
      end

      it 'adds a home page to the site' do
        expect(created_site.pages.pluck(:title, :slug)).to eql([["Home", "/"]])
      end
    end

    context 'when site is not valid' do
      let(:title) { nil }

      it 'does not create a site' do
        expect(outcome.result).to be_blank
      end
    end
  end

  describe '#valid?' do
    context 'with title' do
      it 'is valid' do
        expect(outcome).to be_valid
      end
    end

    context 'without title' do
      let(:title) { nil }

      it 'is not valid' do
        expect(outcome).not_to be_valid
      end
    end
  end
end
