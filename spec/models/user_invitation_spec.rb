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
end
