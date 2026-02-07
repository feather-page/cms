require "rails_helper"

RSpec.describe "Api::V1 Authentication" do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  describe "Bearer token authentication" do
    it "authenticates with valid token" do
      api_token = create(:api_token, user: user)

      get "/api/v1/sites/#{site.public_id}/posts",
          headers: api_headers(token: api_token.token)

      expect(response).to have_http_status(:ok)
    end

    it "rejects invalid token" do
      get "/api/v1/sites/#{site.public_id}/posts",
          headers: api_headers(token: "invalid-token")

      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Unauthorized")
    end

    it "rejects missing Authorization header" do
      get "/api/v1/sites/#{site.public_id}/posts"

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects empty Bearer token" do
      get "/api/v1/sites/#{site.public_id}/posts",
          headers: api_headers(token: "")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "Site authorization" do
    let(:api_token) { create(:api_token, user: user) }
    let(:headers) { api_headers(token: api_token.token) }

    it "allows access to user's site" do
      get "/api/v1/sites/#{site.public_id}/posts", headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "denies access to other user's site" do
      other_site = create(:site)

      get "/api/v1/sites/#{other_site.public_id}/posts", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for nonexistent site" do
      get "/api/v1/sites/nonexistent/posts", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    context "with super admin" do
      let(:admin) { create(:user, :superadmin) }
      let(:admin_token) { create(:api_token, user: admin) }
      let(:admin_headers) { api_headers(token: admin_token.token) }

      it "allows access to any site" do
        other_site = create(:site)

        get "/api/v1/sites/#{other_site.public_id}/posts", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
