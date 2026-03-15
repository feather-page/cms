require "rails_helper"

describe SitesController do
  include_context "authenticated user"

  describe "GET #index" do
    it "shows user's own sites" do
      site = create(:site, users: [user])
      other_site = create(:site)

      get root_path

      expect(response).to be_successful
      expect(response.body).to include(site.title)
      expect(response.body).not_to include(other_site.title)
    end

    context "as superadmin" do
      let(:user) { create(:user, :superadmin) }

      it "shows all sites" do
        site = create(:site)

        get root_path

        expect(response).to be_successful
        expect(response.body).to include(site.title)
      end
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        site: {
          title: "My Site",
          domain: "rocu.de",
          language_code: "fr"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new site" do
        expect do
          post sites_path, params: valid_params
        end.to change(Site, :count).by(1)
      end

      it "returns turbo stream redirect" do
        post sites_path, params: valid_params

        expect(response).to be_successful
        expect(response.body).to include("turbo-stream")
      end
    end

    context "with missing title" do
      let(:invalid_params) do
        {
          site: {
            title: "",
            domain: "rocu.de",
            language_code: "fr"
          }
        }
      end

      it "does not create a site" do
        expect do
          post sites_path, params: invalid_params, as: :turbo_stream
        end.not_to change(Site, :count)
      end

      it "re-renders the form as turbo stream" do
        post sites_path, params: invalid_params, as: :turbo_stream

        expect(response).to be_successful
        expect(response.body).to include("turbo-stream")
      end
    end
  end

  describe "GET #edit" do
    it "returns successful response" do
      get edit_site_path(site)

      expect(response).to be_successful
    end
  end

  describe "PATCH #update" do
    let(:valid_params) do
      {
        site: {
          title: "Updated Title",
          domain: "updated.de",
          language_code: "de",
          emoji: "",
          copyright: "© 2026 Updated"
        }
      }
    end

    context "with valid parameters" do
      it "updates the site" do
        patch site_path(site), params: valid_params

        site.reload
        expect(site.title).to eq("Updated Title")
        expect(site.domain).to eq("updated.de")
        expect(site.language_code).to eq("de")
        expect(site.copyright).to eq("© 2026 Updated")
      end

      it "returns turbo stream redirect" do
        patch site_path(site), params: valid_params

        expect(response).to be_successful
        expect(response.body).to include("turbo-stream")
      end
    end
  end
end
