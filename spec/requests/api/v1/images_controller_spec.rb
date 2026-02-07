require "rails_helper"

RSpec.describe "Api::V1::Images" do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(token: api_token.token) }

  describe "GET /api/v1/sites/:site_id/images/:id" do
    let(:image) { create(:image, site: site) }

    it "returns image metadata" do
      get "/api/v1/sites/#{site.public_id}/images/#{image.public_id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("data", "id")).to eq(image.public_id)
      validate_response_schema!("/sites/{site_id}/images/{id}", "get", 200)
    end

    it "returns 404 for unknown image" do
      get "/api/v1/sites/#{site.public_id}/images/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/sites/:site_id/images" do
    let(:image_url) { "https://example.com/photo.jpg" }
    let(:image_body) { Rails.root.join("spec/fixtures/files/15x15.jpg").read }

    before do
      stub_request(:get, image_url).to_return(
        status: 200,
        body: image_body,
        headers: { "Content-Type" => "image/jpeg" }
      )
    end

    it "creates an image from URL" do
      post "/api/v1/sites/#{site.public_id}/images",
           params: { url: image_url }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response.dig("data", "id")).to be_present
      expect(json_response.dig("data", "source_url")).to eq(image_url)
      validate_response_schema!("/sites/{site_id}/images", "post", 201)
    end

    it "returns 422 for invalid URL" do
      post "/api/v1/sites/#{site.public_id}/images",
           params: { url: "ftp://invalid.com/file.jpg" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for localhost URL" do
      post "/api/v1/sites/#{site.public_id}/images",
           params: { url: "http://localhost/image.jpg" }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
