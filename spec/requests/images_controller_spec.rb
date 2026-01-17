describe ImagesController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }

  describe 'GET #show' do
    let(:image) { create(:image, site:) }

    it 'returns the image' do
      get site_image_path(site, image)

      expect(response.body).to eql(image.file.download)
    end
  end

  describe 'POST #create' do
    it 'creates a new image' do
      post = create(:post, site:)
      params = {
        image: fixture_file_upload('15x15.jpg', 'image/jpeg'),
        imageable_type: 'post',
        imageable_id: post.id
      }
      expect do
        post(site_images_path(site), params:)
      end.to change { site.images.count }.by(1)

      expect(response).to be_successful

      expect(site.images.last.imageable).to eql(post)

      expect(response.parsed_body).to eql(
        { "success" => 1, "id" => site.images.last.id, "file" => { "url" => url_for([site, site.images.last]) } }
      )
    end
  end

  describe 'POST #from_url', :vcr do
    let(:remote_url) { 'https://www.example.com/1.jpg' }

    context 'with working remote url' do
      before do
        stub_request(:get, remote_url).to_return(body: file_fixture('15x15.jpg').read)
      end

      it 'creates a new image' do
        expect do
          post(from_url_site_images_path(site), params: { url: remote_url })
        end.to change { site.images.count }.by(1)

        expect(response).to be_successful

        expect(response.parsed_body).to eql(
          { "success" => 1, "id" => site.images.last.id, "file" => { "url" => url_for([site, site.images.last]) } }
        )
      end
    end

    context 'with failing remote url' do
      before do
        stub_request(:get, remote_url).to_return(status: [500, "Internal Server Error"])
      end

      it 'returns a failed image response' do
        post(from_url_site_images_path(site), params: { url: remote_url })

        expect(response).to be_successful

        expect(response.parsed_body).to eql({ "success" => 0 })
      end
    end
  end
end
