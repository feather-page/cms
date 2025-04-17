describe UserInvitations::Resend do
  context 'when the user is not authorized to resend the invitation' do
    it 'raises an error' do
      user = create(:user)
      invitation = create(:user_invitation)

      outcome = described_class.call(current_user: user, user_invitation: invitation)

      expect(outcome).to be_failure
    end
  end

  context 'when the user is authorized to resend the invitation' do
    it 'updates the inviting user' do
      user = create(:user, :superadmin)
      invitation = create(:user_invitation)

      outcome = described_class.call(current_user: user, user_invitation: invitation)

      expect(outcome).to be_success
      expect(invitation.reload.inviting_user).to eq(user)
    end

    it 'updates the updated_at timestamp' do
      user = create(:user, :superadmin)
      invitation = create(:user_invitation, updated_at: 1.day.ago)

      outcome = described_class.call(current_user: user, user_invitation: invitation)

      expect(outcome).to be_success
      expect(invitation.reload.updated_at).to be_within(1.second).of(Time.current)
    end

    it 'sends an email to the invited user' do
      user = create(:user, :superadmin)
      invitation = create(:user_invitation)

      perform_enqueued_jobs do
        outcome = described_class.call(current_user: user, user_invitation: invitation)
        expect(outcome).to be_success
        expect(ActionMailer::Base.deliveries.count).to eq(1)
      end
    end
  end
end
