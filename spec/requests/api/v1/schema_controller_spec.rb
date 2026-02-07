require "rails_helper"

RSpec.describe "Api::V1::Schema" do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(token: api_token.token) }

  before { Blocks::ContentValidator.reset_schemas! }

  describe "GET /api/v1/sites/:site_id/schema/blocks" do
    it "returns all block type schemas" do
      get "/api/v1/sites/#{site.public_id}/schema/blocks", headers: headers

      expect(response).to have_http_status(:ok)
      block_types = json_response["block_types"]

      expect(block_types.keys).to contain_exactly(
        "paragraph", "header", "code", "image", "quote", "list", "table", "book"
      )
      validate_response_schema!("/sites/{site_id}/schema/blocks", "get", 200)
    end

    it "includes required fields for each block type" do
      get "/api/v1/sites/#{site.public_id}/schema/blocks", headers: headers

      block_types = json_response["block_types"]

      expect(block_types["paragraph"]["required"]).to include("type", "text")
      expect(block_types["header"]["required"]).to include("type", "text", "level")
      expect(block_types["code"]["required"]).to include("type", "code")
      expect(block_types["image"]["required"]).to include("type", "image_id")
      expect(block_types["quote"]["required"]).to include("type", "text", "caption")
      expect(block_types["list"]["required"]).to include("type", "items")
      expect(block_types["table"]["required"]).to include("type", "content")
      expect(block_types["book"]["required"]).to include("type", "book_public_id")
    end

    it "includes header level enum constraints" do
      get "/api/v1/sites/#{site.public_id}/schema/blocks", headers: headers

      header_schema = json_response.dig("block_types", "header", "properties", "level")

      expect(header_schema["enum"]).to eq([2, 3, 4])
    end

    it "includes list style enum constraints" do
      get "/api/v1/sites/#{site.public_id}/schema/blocks", headers: headers

      list_schema = json_response.dig("block_types", "list", "properties", "style")

      expect(list_schema["enum"]).to eq(%w[ul ol])
    end

    it "returns 401 without auth token" do
      get "/api/v1/sites/#{site.public_id}/schema/blocks"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
