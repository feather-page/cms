describe UserInvitation do
  describe 'accepted?' do
    context 'when accepted_at is not set' do
      it 'is not accepted' do
        expect(build(:user_invitation, accepted_at: nil)).not_to be_accepted
      end
    end

    context 'when accepted_at is set' do
      it 'is accepted' do
        expect(build(:user_invitation, accepted_at: DateTime.now)).to be_accepted
      end
    end
  end

  describe 'pending' do
    it 'only returns pending invitations' do
      pending_invitation = create(:user_invitation)
      _accepted_invitation = create(:user_invitation, :accepted)

      expect(described_class.pending).to eq([pending_invitation])
    end
  end
end
