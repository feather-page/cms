require "rails_helper"

RSpec.describe UnsplashImagesController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:unsplash_client) { instance_double(Unsplash::Client) }

  before do
    login_as(user)
    allow(Unsplash::Client).to receive(:new).and_return(unsplash_client)
  end

  describe "GET #search" do
    let(:search_results) do
      [
        instance_double(
          Unsplash::SearchResult,
          id: "abc123",
          description: "A landscape",
          thumbnail_url: "https://example.com/thumb.jpg",
          photographer: { name: "John Doe", profile_url: "https://unsplash.com/@johndoe" }
        )
      ]
    end

    it "returns search results as JSON" do
      allow(unsplash_client).to receive(:search).and_return(search_results)

      get search_site_unsplash_images_path(site), params: { q: "nature" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to eq([
                           {
                             "id" => "abc123",
                             "description" => "A landscape",
                             "thumbnail_url" => "https://example.com/thumb.jpg",
                             "photographer_name" => "John Doe",
                             "photographer_url" => "https://unsplash.com/@johndoe"
                           }
                         ])
    end

    it "returns empty array for blank query" do
      get search_site_unsplash_images_path(site), params: { q: "" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns empty array for query shorter than 2 characters" do
      get search_site_unsplash_images_path(site), params: { q: "a" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end

  describe "POST #create" do
    let(:photo_result) do
      instance_double(
        Unsplash::SearchResult,
        full_url: "https://example.com/photo.jpg",
        unsplash_data: {
          "photographer_name" => "John Doe",
          "photographer_url" => "https://unsplash.com/@johndoe",
          "download_location" => "https://api.unsplash.com/photos/abc123/download"
        }
      )
    end
    let(:remote_image_creator) { instance_double(RemoteImageCreator) }

    before do
      allow(RemoteImageCreator).to receive(:new).and_return(remote_image_creator)
    end

    it "creates an image from unsplash and returns success" do
      allow(unsplash_client).to receive(:photo).and_return(photo_result)
      image = create(:image, site:)
      allow(remote_image_creator).to receive(:create_from).and_return(image)

      post site_unsplash_images_path(site), params: { unsplash_id: "abc123" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["success"]).to be true
      expect(json["image_id"]).to eq(image.id)
    end

    it "returns failure when photo not found" do
      allow(unsplash_client).to receive(:photo).and_return(nil)

      post site_unsplash_images_path(site), params: { unsplash_id: "invalid" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["success"]).to be false
    end

    it "returns failure when image creation fails" do
      allow(unsplash_client).to receive(:photo).and_return(photo_result)
      allow(remote_image_creator).to receive(:create_from).and_return(nil)

      post site_unsplash_images_path(site), params: { unsplash_id: "abc123" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["success"]).to be false
    end
  end
end
