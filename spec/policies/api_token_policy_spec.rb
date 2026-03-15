require "rails_helper"

describe ApiTokenPolicy do
  subject(:policy) { described_class }

  let(:site) { create(:site) }
  let(:token_owner) { create(:user, sites: [site]) }
  let!(:api_token) { create(:api_token, user: token_owner) }

  permissions :create? do
    it "permits any signed-in user" do
      expect(policy).to permit(create(:user), ApiToken)
    end

    it "denies anonymous user" do
      expect(policy).not_to permit(nil, ApiToken)
    end
  end

  permissions :destroy? do
    it "permits the token owner" do
      expect(policy).to permit(token_owner, api_token)
    end

    it "permits a super admin" do
      expect(policy).to permit(build(:user, :superadmin), api_token)
    end

    it "denies another user" do
      expect(policy).not_to permit(create(:user), api_token)
    end
  end

  describe "Scope" do
    let(:other_user) { create(:user) }
    let!(:other_token) { create(:api_token, user: other_user) }

    it "returns all tokens for super admin" do
      admin = build(:user, :superadmin)
      scope = described_class::Scope.new(admin, ApiToken).resolve
      expect(scope).to include(api_token, other_token)
    end

    it "returns only own tokens for regular user" do
      scope = described_class::Scope.new(token_owner, ApiToken).resolve
      expect(scope).to include(api_token)
      expect(scope).not_to include(other_token)
    end
  end
end
