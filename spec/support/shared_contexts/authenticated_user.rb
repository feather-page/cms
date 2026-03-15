RSpec.shared_context "authenticated user" do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }
end

RSpec.shared_context "authenticated superadmin" do
  let(:user) { create(:user, :superadmin) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }
end

RSpec.shared_context "authenticated api user" do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(token: api_token.plain_token) }
end
