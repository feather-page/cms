require "rails_helper"

describe UserInvitationsController do
  include_context "authenticated superadmin"

  describe "GET #new" do
    it "returns successful response" do
      get new_site_invitation_path(site)
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    it "creates an invitation" do
      expect {
        post site_invitations_path(site), params: { user_invitation: { email: "new@example.com" } }
      }.to change(UserInvitation, :count).by(1)
    end

    it "sets a success notice" do
      post site_invitations_path(site), params: { user_invitation: { email: "new@example.com" } }
      expect(flash[:notice]).to be_present
    end

    context "when the user already exists" do
      it "still creates an invitation without duplicating the user" do
        existing_user = create(:user)

        expect {
          post site_invitations_path(site), params: { user_invitation: { email: existing_user.email } }
        }.to change(UserInvitation, :count).by(1)
           .and change(User, :count).by(0)
      end
    end
  end

  describe "POST #resend" do
    it "resends the invitation" do
      invitation = create(:user_invitation, site: site, inviting_user: user)

      post resend_invitation_path(invitation)

      expect(flash[:notice]).to be_present
    end
  end

  describe "DELETE #destroy" do
    it "destroys the invitation" do
      invitation = create(:user_invitation, site: site, inviting_user: user)

      expect {
        delete invitation_path(invitation)
      }.to change(UserInvitation, :count).by(-1)
    end

    it "sets a success notice" do
      invitation = create(:user_invitation, site: site, inviting_user: user)

      delete invitation_path(invitation)

      expect(flash[:notice]).to be_present
    end
  end

  describe "GET #edit (accept page)" do
    before { login_as(nil) }

    context "when invitation is pending" do
      it "returns successful response" do
        invitation = create(:user_invitation)

        get edit_invitation_path(id: invitation.accept_invitation_token)

        expect(response).to be_successful
      end
    end

    context "when invitation was already accepted" do
      it "redirects to root with already-accepted notice" do
        invitation = create(:user_invitation, :accepted)

        get edit_invitation_path(id: invitation.accept_invitation_token)

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to be_present
      end
    end
  end

  describe "PATCH #update (accept invitation)" do
    before { login_as(nil) }

    context "when invitation is pending" do
      it "creates a user and adds them to the site" do
        invitation = create(:user_invitation)

        expect {
          patch invitation_path(id: invitation.accept_invitation_token)
        }.to change(User, :count).by(1)

        created_user = User.find_by(email: invitation.email)
        expect(created_user).to be_present
        expect(created_user.sites).to include(invitation.site)
      end

      it "marks the invitation as accepted" do
        invitation = create(:user_invitation)

        patch invitation_path(id: invitation.accept_invitation_token)

        expect(invitation.reload).to be_accepted
      end

      it "sets a success notice" do
        invitation = create(:user_invitation)

        patch invitation_path(id: invitation.accept_invitation_token)

        expect(flash[:notice]).to be_present
      end
    end
  end
end
