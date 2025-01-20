describe InviteUser do
  subject(:outcome) do
    described_class.execute(site:, current_user:, email:)
  end

  let(:site) { create(:site) }
  let(:current_user) { create(:user) }

  context 'when inviting_user is authorized to invite users' do
    before do
      site.users << current_user
    end

    context 'with a valid email' do
      let(:email) { Faker::Internet.email }

      it 'works' do
        expect(outcome).to be_success
      end

      it 'creates a user invitation' do
        expect(outcome.user_invitation).to be_persisted
        expect(outcome.user_invitation.site).to eq(site)
        expect(outcome.user_invitation.email).to eq(email)
      end

      it 'sends an email to the invited user' do
        expect do
          ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
          outcome
          ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
        end.to change(ActionMailer::Base.deliveries, :count).by(1)
      end
    end
  end
end
