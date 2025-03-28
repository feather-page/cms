require "rails_helper"

RSpec.describe UserMailer do
  describe "#login" do
    let(:user) { build(:user) }
    let(:site) { build(:site) }
    let(:mail) { described_class.with(user:, site:).login }

    it "renders the headers" do
      expect(mail.subject).to eq("Your login-link from feather.page")
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(["no-reply@feather.page"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Your Login-link from feather.page")
    end
  end
end
