# Unsplash image search step definitions

Given("the Unsplash API is available") do
  @unsplash_results = [
    {
      "id" => "abc123",
      "description" => "A beautiful landscape",
      "alt_description" => "Mountains and trees",
      "urls" => { "thumb" => "https://images.unsplash.com/thumb.jpg",
                  "regular" => "https://images.unsplash.com/regular.jpg" },
      "user" => { "name" => "John Doe", "links" => { "html" => "https://unsplash.com/@johndoe" } },
      "links" => { "download_location" => "https://api.unsplash.com/photos/abc123/download" }
    }
  ]

  stub_request(:get, %r{api\.unsplash\.com/search/photos})
    .to_return(status: 200, body: { "results" => @unsplash_results }.to_json,
               headers: { 'Content-Type' => 'application/json' })
end

Given("an Unsplash photo {string} exists") do |photo_id|
  photo_data = {
    "id" => photo_id,
    "description" => "A beautiful landscape",
    "alt_description" => "Mountains and trees",
    "urls" => { "thumb" => "https://images.unsplash.com/thumb.jpg",
                "regular" => "https://images.unsplash.com/regular.jpg" },
    "user" => { "name" => "John Doe", "links" => { "html" => "https://unsplash.com/@johndoe" } },
    "links" => { "download_location" => "https://api.unsplash.com/photos/#{photo_id}/download" }
  }

  stub_request(:get, %r{api\.unsplash\.com/photos/#{photo_id}})
    .to_return(status: 200, body: photo_data.to_json, headers: { 'Content-Type' => 'application/json' })

  stub_request(:get, "https://images.unsplash.com/regular.jpg")
    .to_return(status: 200, body: Rails.root.join('spec/fixtures/files/15x15.jpg').read,
               headers: { 'Content-Type' => 'image/jpeg' })
end

When("I search for {string} on Unsplash") do |query|
  site = Site.find_by(title: "My Blog")
  page.driver.get(search_site_unsplash_images_path(site, q: query))
  @unsplash_response = JSON.parse(page.body)
end

When("I add the Unsplash photo {string} to my site") do |photo_id|
  site = Site.find_by(title: "My Blog")
  page.driver.post(site_unsplash_images_path(site), unsplash_id: photo_id)
  @create_response = JSON.parse(page.body)
end

Then("I should see Unsplash search results") do
  expect(@unsplash_response).to be_an(Array)
  expect(@unsplash_response).not_to be_empty
end

Then("each result should have a thumbnail and photographer info") do
  @unsplash_response.each do |result|
    expect(result).to have_key("thumbnail_url")
    expect(result).to have_key("photographer_name")
    expect(result).to have_key("photographer_url")
  end
end

Then("I should see no Unsplash results") do
  expect(@unsplash_response).to eq([])
end

Then("the image should be saved to my site") do
  expect(@create_response["success"]).to be true
  expect(@create_response["image_id"]).to be_present
end

Then("the image should have Unsplash attribution data") do
  image = Image.find(@create_response["image_id"])
  expect(image.unsplash_data).to be_present
  expect(image.unsplash_data["photographer_name"]).to be_present
end
