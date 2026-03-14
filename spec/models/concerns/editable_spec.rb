describe Editable do
  describe 'assign images after create' do
    it 'assigns images' do
      imageable = build(:post)
      image = create(:image, imageable: nil)

      imageable.content = {
        "blocks" =>
        [{
          "id" => "3VXVq1RLaU",
          "type" => "image",
          "data" => {
            "file" => {
              "url" => "https://example.com/images/#{image.id}"
            }
          }
        }]
      }.to_json

      imageable.save

      expect(imageable.images.to_a).to eq([image])
    end
  end

  describe 'destroy with image references' do
    it 'destroys a post that has a thumbnail image' do
      post = create(:post, :with_thumbnail_image)

      expect { post.destroy! }.to change(Post, :count).by(-1)
    end

    it 'destroys a post that has a header image' do
      post = create(:post)
      image = create(:image, imageable: post, site: post.site)
      post.update!(header_image: image)

      expect { post.destroy! }.to change(Post, :count).by(-1)
    end
  end
end
