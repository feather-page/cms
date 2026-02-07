require "rails_helper"

RSpec.describe "Api::V1::Pages" do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(token: api_token.plain_token) }

  describe "GET /api/v1/sites/:site_id/pages" do
    it "returns all pages for the site" do
      create_list(:page, 2, site: site)

      get "/api/v1/sites/#{site.public_id}/pages", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].length).to eq(2)
      validate_response_schema!("/sites/{site_id}/pages", "get", 200)
    end

    it "returns 401 without auth token" do
      get "/api/v1/sites/#{site.public_id}/pages"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for unauthorized site" do
      other_site = create(:site)

      get "/api/v1/sites/#{other_site.public_id}/pages", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/sites/:site_id/pages/:id" do
    let(:page_record) { create(:page, site: site, title: "About") }

    it "returns the page" do
      get "/api/v1/sites/#{site.public_id}/pages/#{page_record.public_id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("data", "title")).to eq("About")
      validate_response_schema!("/sites/{site_id}/pages/{id}", "get", 200)
    end

    it "returns 404 for unknown page" do
      get "/api/v1/sites/#{site.public_id}/pages/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/sites/:site_id/pages" do
    let(:valid_params) do
      {
        page: {
          title: "About Me",
          slug: "about",
          content: [
            { type: "paragraph", text: "I am a developer." }
          ]
        }
      }
    end

    it "creates a page with valid params" do
      post "/api/v1/sites/#{site.public_id}/pages",
           params: valid_params.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response.dig("data", "title")).to eq("About Me")
      expect(json_response.dig("data", "slug")).to eq("about")
      validate_response_schema!("/sites/{site_id}/pages", "post", 201)
    end

    it "creates a homepage with slug /" do
      post "/api/v1/sites/#{site.public_id}/pages",
           params: { page: { title: "Home", slug: "/" } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response.dig("data", "slug")).to eq("/")
    end

    it "creates a page with page_type" do
      post "/api/v1/sites/#{site.public_id}/pages",
           params: { page: { title: "Books", slug: "books", page_type: "books" } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response.dig("data", "page_type")).to eq("books")
    end

    it "returns 422 for missing slug" do
      post "/api/v1/sites/#{site.public_id}/pages",
           params: { page: { title: "No Slug" } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["details"]["slug"]).to be_present
    end

    it "returns 422 for invalid content blocks" do
      post "/api/v1/sites/#{site.public_id}/pages",
           params: { page: { title: "Bad", slug: "bad", content: [{ type: "list" }] } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]).to include("Content validation failed")
    end
  end

  describe "PATCH /api/v1/sites/:site_id/pages/:id" do
    let(:page_record) { create(:page, site: site, title: "Original") }

    it "updates the page" do
      patch "/api/v1/sites/#{site.public_id}/pages/#{page_record.public_id}",
            params: { page: { title: "Updated" } }.to_json,
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("data", "title")).to eq("Updated")
      validate_response_schema!("/sites/{site_id}/pages/{id}", "patch", 200)
    end

    it "updates content blocks" do
      patch "/api/v1/sites/#{site.public_id}/pages/#{page_record.public_id}",
            params: { page: { content: [{ type: "paragraph", text: "New content" }] } }.to_json,
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("data", "content").length).to eq(1)
    end
  end

  describe "DELETE /api/v1/sites/:site_id/pages/:id" do
    let!(:page_record) { create(:page, site: site) }

    it "deletes the page" do
      expect do
        delete "/api/v1/sites/#{site.public_id}/pages/#{page_record.public_id}", headers: headers
      end.to change(Page, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to eq("Page deleted")
    end
  end
end
