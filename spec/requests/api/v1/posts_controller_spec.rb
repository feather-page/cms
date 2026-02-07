require "rails_helper"

RSpec.describe "Api::V1::Posts" do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(token: api_token.token) }

  describe "GET /api/v1/sites/:site_id/posts" do
    it "returns all posts for the site" do
      create_list(:post, 3, site: site)

      get "/api/v1/sites/#{site.public_id}/posts", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"].length).to eq(3)
      validate_response_schema!("/sites/{site_id}/posts", "get", 200)
    end

    it "returns empty array when no posts exist" do
      get "/api/v1/sites/#{site.public_id}/posts", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
      validate_response_schema!("/sites/{site_id}/posts", "get", 200)
    end

    it "returns 401 without auth token" do
      get "/api/v1/sites/#{site.public_id}/posts"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for unauthorized site" do
      other_site = create(:site)

      get "/api/v1/sites/#{other_site.public_id}/posts", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/sites/:site_id/posts/:id" do
    let(:post_record) { create(:post, site: site, title: "My Post") }

    it "returns the post" do
      get "/api/v1/sites/#{site.public_id}/posts/#{post_record.public_id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("data", "title")).to eq("My Post")
      validate_response_schema!("/sites/{site_id}/posts/{id}", "get", 200)
    end

    it "returns 404 for unknown post" do
      get "/api/v1/sites/#{site.public_id}/posts/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/sites/:site_id/posts" do
    let(:valid_params) do
      {
        post: {
          title: "New Post",
          slug: "/new-post",
          content: [
            { type: "header", text: "Hello", level: 2 },
            { type: "paragraph", text: "World" }
          ]
        }
      }
    end

    it "creates a post with valid params" do
      post "/api/v1/sites/#{site.public_id}/posts",
           params: valid_params.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response.dig("data", "title")).to eq("New Post")
      expect(json_response.dig("data", "slug")).to eq("/new-post")
      expect(json_response.dig("data", "content").length).to eq(2)
      validate_response_schema!("/sites/{site_id}/posts", "post", 201)
    end

    it "creates a post without content" do
      post "/api/v1/sites/#{site.public_id}/posts",
           params: { post: { title: "No content" } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      validate_response_schema!("/sites/{site_id}/posts", "post", 201)
    end

    it "creates a post as draft" do
      post "/api/v1/sites/#{site.public_id}/posts",
           params: { post: { title: "Draft", draft: true } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response.dig("data", "draft")).to be true
    end

    it "returns 422 for invalid content blocks" do
      post "/api/v1/sites/#{site.public_id}/posts",
           params: { post: { title: "Bad", content: [{ type: "header", text: "No level" }] } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]).to include("Content validation failed")
      expect(json_response["details"]["content"]).to be_present
    end

    it "returns 422 for unknown block type" do
      post "/api/v1/sites/#{site.public_id}/posts",
           params: { post: { title: "Bad", content: [{ type: "fancy" }] } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["details"]["content"].first).to include("unknown or missing type")
    end

    it "returns 422 for duplicate slug" do
      create(:post, site: site, slug: "/duplicate")

      post "/api/v1/sites/#{site.public_id}/posts",
           params: { post: { title: "Dup", slug: "/duplicate" } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]).to eq("Validation failed")
    end
  end

  describe "PATCH /api/v1/sites/:site_id/posts/:id" do
    let(:post_record) { create(:post, site: site, title: "Original") }

    it "updates the post" do
      patch "/api/v1/sites/#{site.public_id}/posts/#{post_record.public_id}",
            params: { post: { title: "Updated" } }.to_json,
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("data", "title")).to eq("Updated")
      validate_response_schema!("/sites/{site_id}/posts/{id}", "patch", 200)
    end

    it "updates content blocks" do
      patch "/api/v1/sites/#{site.public_id}/posts/#{post_record.public_id}",
            params: { post: { content: [{ type: "paragraph", text: "Updated content" }] } }.to_json,
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.dig("data", "content").length).to eq(1)
    end

    it "rejects invalid content" do
      patch "/api/v1/sites/#{site.public_id}/posts/#{post_record.public_id}",
            params: { post: { content: [{ type: "header" }] } }.to_json,
            headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/v1/sites/:site_id/posts/:id" do
    let!(:post_record) { create(:post, site: site) }

    it "deletes the post" do
      expect do
        delete "/api/v1/sites/#{site.public_id}/posts/#{post_record.public_id}", headers: headers
      end.to change(Post, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to eq("Post deleted")
    end

    it "returns 404 for unknown post" do
      delete "/api/v1/sites/#{site.public_id}/posts/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
