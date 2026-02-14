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
    it "exposes plain_token only after creation" do
      user = create(:user)
      token = described_class.create!(user: user, name: "test")

      expect(token.plain_token).to be_present
      expect(token.plain_token.length).to eq(64)
    end

    it "stores a SHA256 digest, not the plain token" do
      user = create(:user)
      token = described_class.create!(user: user, name: "test")
      expected_digest = Digest::SHA256.hexdigest(token.plain_token)

      expect(token.token_digest).to eq(expected_digest)
      expect(token.token_digest).not_to eq(token.plain_token)
    end

    it "stores the first 8 characters as token_prefix" do
      user = create(:user)
      token = described_class.create!(user: user, name: "test")

      expect(token.token_prefix).to eq(token.plain_token[0, 8])
    end

    it "does not expose plain_token when loaded from database" do
      user = create(:user)
      token = described_class.create!(user: user, name: "test")
      found = described_class.find(token.id)

      expect(found.plain_token).to be_nil
    end

    it "generates unique digests" do
      user = create(:user)
      token1 = described_class.create!(user: user, name: "first")
      token2 = described_class.create!(user: user, name: "second")

      expect(token1.token_digest).not_to eq(token2.token_digest)
    end
  end

  describe ".authenticate" do
    it "finds a token by plain token value" do
      user = create(:user)
      token = described_class.create!(user: user, name: "test")

      found = described_class.authenticate(token.plain_token)

      expect(found).to eq(token)
    end

    it "returns nil for invalid token" do
      expect(described_class.authenticate("invalid")).to be_nil
    end

    it "returns nil for blank token" do
      expect(described_class.authenticate("")).to be_nil
      expect(described_class.authenticate(nil)).to be_nil
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
