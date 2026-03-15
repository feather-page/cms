require "rails_helper"

describe SessionsController do
  describe "GET #new" do
    it "returns successful response" do
      get login_path
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    context "with existing user email" do
      let!(:user) { create(:user, email: "test@example.com") }

      it "sends a login email" do
        expect {
          post login_path, params: { email: "test@example.com" }, as: :turbo_stream
        }.to have_enqueued_mail(UserMailer, :login)
      end

      it "returns successful response" do
        post login_path, params: { email: "test@example.com" }, as: :turbo_stream
        expect(response).to be_successful
      end
    end

    context "with non-existing email" do
      it "does not send an email" do
        expect {
          post login_path, params: { email: "unknown@example.com" }, as: :turbo_stream
        }.not_to have_enqueued_mail(UserMailer, :login)
      end

      it "returns successful response" do
        post login_path, params: { email: "unknown@example.com" }, as: :turbo_stream
        expect(response).to be_successful
      end
    end
  end

  describe "GET #show" do
    context "with valid token" do
      let(:user) { create(:user) }
      let(:token) { user.generate_token_for(:email_login) }

      it "logs in and redirects to root" do
        get login_token_path(token: token)
        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid token" do
      it "redirects to root without logging in" do
        get login_token_path(token: "invalid-token")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE #destroy" do
    it "logs out and redirects" do
      user = create(:user)
      login_as(user)

      delete logout_path, as: :turbo_stream
      expect(response).to be_successful
    end
  end
end
