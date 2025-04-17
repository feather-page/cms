describe UserInvitations::Accept do
  let(:user_invitation) { create(:user_invitation) }
  let(:outcome) { described_class.call(user_invitation:) }
  let(:user) { outcome.user }

  it 'creates a new user' do
    expect(outcome).to be_success
    expect(user).to be_persisted
    expect(user.email).to eq(user_invitation.email)
  end

  it 'associates the user to the site' do
    expect(user.sites).to include(user_invitation.site)
  end

  it 'marks the invitaions as accepted' do
    outcome
    expect(user_invitation.reload).to be_accepted
  end

  it 'sends a notice to the inviting user' do
    perform_enqueued_jobs do
      expect { outcome }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
