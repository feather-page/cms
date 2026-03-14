require "rails_helper"

describe SiteUsersController do
  let(:user) { create(:user, :superadmin) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }

  describe "GET #index" do
    it "returns successful response" do
      get site_users_path(site)
      expect(response).to be_successful
    end

    it "shows all site users" do
      users = create_list(:user, 3, sites: [site])
      get site_users_path(site)
      users.each { |u| expect(response.body).to include(u.email) }
    end
  end

  describe "DELETE #destroy" do
    it "removes the user from the site" do
      site_user = create(:site_user, site: site)
      expect {
        delete site_user_path(site, site_user)
      }.to change(SiteUser, :count).by(-1)
    end

    it "returns successful response" do
      site_user = create(:site_user, site: site)
      delete site_user_path(site, site_user)
      expect(response).to be_successful
    end
  end
end
