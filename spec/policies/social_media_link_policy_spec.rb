require "rails_helper"

describe SocialMediaLinkPolicy do
  subject(:policy) { described_class }

  let(:site) { create(:site) }
  let!(:link) { create(:social_media_link, site: site) }

  permissions :destroy? do
    it "permits a super admin" do
      expect(policy).to permit(build(:user, :superadmin), link)
    end

    it "permits a user that is part of the site" do
      expect(policy).to permit(create(:user, sites: [site]), link)
    end

    it "denies a user that is not part of the site" do
      expect(policy).not_to permit(create(:user), link)
    end
  end

  describe "Scope" do
    let(:site_user) { create(:user, sites: [site]) }

    it "returns all links for super admin" do
      admin = create(:user, :superadmin)
      scope = described_class::Scope.new(admin, SocialMediaLink).resolve
      expect(scope).to include(link)
    end

    it "returns only site links for site member" do
      other_link = create(:social_media_link, site: create(:site))
      scope = described_class::Scope.new(site_user, SocialMediaLink).resolve
      expect(scope).to include(link)
      expect(scope).not_to include(other_link)
    end
  end
end
