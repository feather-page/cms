require "rails_helper"

describe SocialMediaLinksController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }

  describe "POST #create" do
    it "creates a social media link" do
      expect {
        post site_social_media_links_path(site), params: {
          social_media_link: { name: "Instagram", url: "https://instagram.com/example", icon: "instagram" }
        }
      }.to change(SocialMediaLink, :count).by(1)
    end

    it "associates the link with the site" do
      post site_social_media_links_path(site), params: {
        social_media_link: { name: "Instagram", url: "https://instagram.com/example", icon: "instagram" }
      }
      expect(SocialMediaLink.last.site).to eq(site)
    end

    it "returns turbo stream redirect" do
      post site_social_media_links_path(site), params: {
        social_media_link: { name: "Instagram", url: "https://instagram.com/example", icon: "instagram" }
      }
      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "DELETE #destroy" do
    it "deletes the social media link" do
      link = create(:social_media_link, site: site)
      expect {
        delete site_social_media_link_path(site, link)
      }.to change(SocialMediaLink, :count).by(-1)
    end

    it "returns successful response" do
      link = create(:social_media_link, site: site)
      delete site_social_media_link_path(site, link)
      expect(response).to be_successful
    end
  end
end
