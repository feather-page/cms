describe Api::LinksController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before do
    login_as(user)
  end

  describe 'GET /api/sites/:site_id/links' do
    let!(:page) { create(:page, site:, title: 'About Us', slug: '/about', emoji: nil) }
    let!(:post_with_slug) { create(:post, site:, title: 'My First Post', slug: '/my-first-post', emoji: nil) }
    let!(:post_without_slug) { create(:post, site:, title: 'Short Post', slug: nil) }

    it 'returns success with items' do
      get "/api/sites/#{site.public_id}/links"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['success']).to be true
      expect(json['items']).to be_an(Array)
    end

    it 'includes pages in results' do
      get "/api/sites/#{site.public_id}/links"

      json = response.parsed_body
      page_item = json['items'].find { |i| i['name'] == 'About Us' }

      expect(page_item).to be_present
      expect(page_item['href']).to eq('/about')
      expect(page_item['description']).to eq('Page')
      expect(page_item['sgid']).to be_present
    end

    it 'includes posts with slugs in results' do
      get "/api/sites/#{site.public_id}/links"

      json = response.parsed_body
      post_item = json['items'].find { |i| i['name'] == 'My First Post' }

      expect(post_item).to be_present
      expect(post_item['href']).to eq('/my-first-post')
      expect(post_item['description']).to eq('Post')
      expect(post_item['sgid']).to be_present
    end

    it 'excludes posts without slugs' do
      get "/api/sites/#{site.public_id}/links"

      json = response.parsed_body
      short_post_item = json['items'].find { |i| i['name'] == 'Short Post' }

      expect(short_post_item).to be_nil
    end

    context 'with search query' do
      it 'filters results by title' do
        get "/api/sites/#{site.public_id}/links", params: { search: 'about' }

        json = response.parsed_body
        expect(json['items'].length).to eq(1)
        expect(json['items'].first['name']).to eq('About Us')
      end

      it 'is case insensitive' do
        get "/api/sites/#{site.public_id}/links", params: { search: 'ABOUT' }

        json = response.parsed_body
        expect(json['items'].length).to eq(1)
        expect(json['items'].first['name']).to eq('About Us')
      end
    end

    context 'with emoji' do
      let!(:page_with_emoji) { create(:page, site:, title: 'Contact', slug: '/contact', emoji: '📧') }

      it 'includes emoji in name' do
        get "/api/sites/#{site.public_id}/links"

        json = response.parsed_body
        contact_item = json['items'].find { |i| i['href'] == '/contact' }

        expect(contact_item['name']).to eq('📧 Contact')
      end
    end

    context 'when not authenticated' do
      # rubocop:disable RSpec/AnyInstance
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end
      # rubocop:enable RSpec/AnyInstance

      it 'redirects to login' do
        get "/api/sites/#{site.public_id}/links"

        expect(response).to redirect_to(login_path)
      end
    end

    context 'when accessing another site' do
      let(:other_site) { create(:site) }

      it 'returns not found' do
        expect do
          get "/api/sites/#{other_site.public_id}/links"
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end
