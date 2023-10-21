describe Api::SlugsController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before do
    login_as(user)
  end

  context 'when slug does not exist' do
    it 'returns http success' do
      post "/api/sites/#{site.public_id}/slugs", params: { slug: '/foobar' }

      expect(response).to have_http_status(:ok)
    end
  end

  context 'when slug does exist' do
    it 'returns :locked and returns a alternative' do
      create(:post, slug: '/foobar', site:)
      post "/api/sites/#{site.public_id}/slugs", params: { slug: '/foobar' }

      expect(response).to have_http_status(:locked)
      expect(response.body).to eq('/foobar1')
    end
  end
end
