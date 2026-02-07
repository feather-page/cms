require "rails_helper"

RSpec.describe ApiToken do
  describe "associations" do
    it "belongs to a user" do
      user = create(:user)
      token = create(:api_token, user: user)

      expect(token.user).to eq(user)
    end
  end

  describe "validations" do
    it "requires a user" do
      token = described_class.new(name: "test")

      expect(token).not_to be_valid
      expect(token.errors[:user]).to be_present
    end
  end

  describe "token generation" do
    it "auto-generates a token on create" do
      user = create(:user)
      token = described_class.create!(user: user, name: "test")

      expect(token.token).to be_present
      expect(token.token.length).to eq(64)
    end

    it "generates unique tokens" do
      user = create(:user)
      token1 = described_class.create!(user: user, name: "first")
      token2 = described_class.create!(user: user, name: "second")

      expect(token1.token).not_to eq(token2.token)
    end
  end

  describe "user association" do
    it "is destroyed when user is destroyed" do
      user = create(:user)
      create(:api_token, user: user)

      expect { user.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
