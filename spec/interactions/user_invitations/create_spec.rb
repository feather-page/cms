describe UserInvitations::Create do
  subject(:outcome) do
    described_class.call(site:, current_user:, email:)
  end

  let(:site) { create(:site) }
  let(:current_user) { create(:user) }

  context 'when inviting_user is authorized to invite users' do
    before do
      site.users << current_user
    end

    context 'with a valid email' do
      let(:email) { Faker::Internet.email }

      it 'creates a user invitation' do
        expect(outcome).to be_success
        expect(outcome.user_invitation).to be_persisted
        expect(outcome.user_invitation.site).to eq(site)
        expect(outcome.user_invitation.email).to eq(email)
      end

      it 'sends an email to the invited user' do
        perform_enqueued_jobs do
          expect do
            outcome
          end.to change(ActionMailer::Base.deliveries, :count).by(1)
        end
      end
    end
  end
end
