describe UserInvitationMailer do
  describe "invite" do
    let(:user_invitation) { create(:user_invitation) }
    let(:mail) { described_class.invite(user_invitation) }

    it "renders the headers" do
      expect(mail.to).to eq([user_invitation.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq("You have been invited to #{user_invitation.site.title} on feather.page")
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Someone invited you to join their site on feather.page")
    end
  end

  describe "invite_accepted" do
    let(:user_invitation) { create(:user_invitation) }
    let(:mail) { described_class.invite_accepted(user_invitation) }

    it "renders the headers" do
      expect(mail.to).to eq([user_invitation.inviting_user.email])
    end

    it "renders the subject" do
      expect(mail.subject).to eq(
        "The user #{user_invitation.email} accepted your invitation to #{user_invitation.site.title}."
      )
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("You can now collaborate on the site together.")
    end
  end
end
