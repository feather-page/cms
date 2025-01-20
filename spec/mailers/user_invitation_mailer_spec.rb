require "rails_helper"

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
end
