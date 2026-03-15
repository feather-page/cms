describe RemoteImageCreator do
  subject(:creator) { described_class.new(site, imageable) }

  let(:site) { create(:site) }
  let(:imageable) { create(:post, site:) }
  let(:image_url) { 'https://example.com/image.jpg' }

  describe '#create_from' do
    context 'when remote GET request does work' do
      before do
        stub_request(:get, image_url).to_return(body: file_fixture('15x15.jpg').read)
      end

      it 'creates an image' do
        image = creator.create_from(image_url)

        expect(image).to be_persisted
        expect(image.file).to be_attached
        expect(image.source_url).to eq(image_url)
      end
    end

    context 'when remote GET request returns a failed response' do
      before do
        stub_request(:get, image_url).to_return(status: [500, "Internal Server Error"])
      end

      it 'raises an error' do
        expect do
          creator.create_from(image_url)
        end.to raise_error(RemoteImageCreator::Error, "Failed to fetch image from #{image_url}. Status: 500")
      end
    end

    context 'when remote GET request returns a redirect' do
      let(:redirect_url) { 'https://example.com/redirected-image.jpg' }

      before do
        stub_request(:get, image_url).to_return(status: 302, headers: { 'Location' => redirect_url })
        stub_request(:get, redirect_url).to_return(body: file_fixture('15x15.jpg').read)
      end

      it 'follows the redirect and creates an image' do
        image = creator.create_from(image_url)

        expect(image).to be_persisted
        expect(image.file).to be_attached
      end
    end

    context 'when redirect has no location header' do
      before do
        stub_request(:get, image_url).to_return(status: 302, headers: {})
      end

      it 'raises an error for the non-success status' do
        expect do
          creator.create_from(image_url)
        end.to raise_error(RemoteImageCreator::Error, /Status: 302/)
      end
    end

    context 'when redirect exceeds max redirects' do
      before do
        stub_request(:get, image_url).to_return(status: 302, headers: { 'Location' => image_url })
      end

      it 'raises an error after exhausting redirects' do
        expect do
          creator.create_from(image_url)
        end.to raise_error(RemoteImageCreator::Error, /Status: 302/)
      end
    end

    context 'when remote GET request throws a farraday error' do
      before do
        stub_request(:get, image_url).to_raise(Faraday::Error.new('Connection failed'))
      end

      it 'raises an error' do
        expect do
          creator.create_from(image_url)
        end.to raise_error(
          RemoteImageCreator::Error,
          "Failed to fetch image from #{image_url}. Error: Connection failed"
        )
      end
    end
  end
end
