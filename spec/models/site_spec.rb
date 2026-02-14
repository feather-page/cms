describe Site do
  describe '.publish' do
    context 'when no target type is specified' do
      it 'publishes to staging' do
        site = create(:site)
        deployment_target = create(:deployment_target, type: :staging, provider: :internal, site:)

        site.publish

        expect(Hugo::BuildJob).to have_been_enqueued.with(deployment_target)
      end
    end
  end

  describe 'validations' do
    describe 'emoji' do
      it 'only allows emoji' do
        site = build(:site, emoji: '🎉')

        expect(site).to be_valid
      end

      it 'allows complex emojis' do
        site = build(:site, emoji: '👨‍💻')

        expect(site).to be_valid
      end

      it 'does not allow non-emoji' do
        site = build(:site, emoji: 'A')

        expect(site).not_to be_valid
      end
    end
  end
end
