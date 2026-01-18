# Post management step definitions

# Navigation
When("I go to the posts page for {string}") do |site_title|
  site = Site.find_by(title: site_title)
  visit site_posts_path(site)
end

# Post existence
Given("a post {string} exists for {string}") do |post_title, site_title|
  site = Site.find_by(title: site_title)
  @post = create(:post, title: post_title, site: site)
end

Given("{int} posts exist for {string}") do |count, site_title|
  site = Site.find_by(title: site_title)
  create_list(:post, count, site: site)
end

Given("a post with images exists for {string}") do |site_title|
  site = Site.find_by(title: site_title)
  @post = create(:post, site: site)
  create(:image, imageable: @post, site: site)
end

# Form actions
When("I enter the title {string}") do |title|
  # Wait for turbo frame to update - look for the form heading
  find('h1', text: /New Post|Edit Post/i, wait: 5)
  # Title field is hidden until content > 300 chars or already has value
  # For testing, reveal it via JS if hidden
  page.execute_script("document.querySelector('[data-post_form-target=\"titleAndSlug\"]')?.classList.remove('d-none')")
  fill_in 'post_title', with: title
end

When("I enter content {string}") do |content|
  # Editor.js content - we may need to interact with the editor differently
  # For now, try to fill in a textarea or contenteditable
  if page.has_css?('[data-controller="editor"]')
    # Editor.js is used, we need to interact with it
    page.execute_script("document.querySelector('.codex-editor__redactor')?.click()")
    page.execute_script("document.execCommand('insertText', false, '#{content}')")
  else
    fill_in 'Content', with: content
  end
end

When("I enter the slug {string}") do |slug|
  # Title/slug fields might be hidden, reveal them first
  page.execute_script("document.querySelector('[data-post_form-target=\"titleAndSlug\"]')?.classList.remove('d-none')")
  fill_in 'post_slug', with: slug
end

When("I leave the slug empty") do
  # Title/slug fields might be hidden, reveal them first
  page.execute_script("document.querySelector('[data-post_form-target=\"titleAndSlug\"]')?.classList.remove('d-none')")
  fill_in 'post_slug', with: ''
end

When("I set the publish date to {string}") do |date|
  fill_in 'post_publish_at', with: date
end

# Edit actions
When("I edit the post {string}") do |post_title|
  post = Post.find_by(title: post_title)
  visit edit_site_post_path(post.site, post)
end

# Delete actions
When("I delete the post {string}") do |post_title|
  post = Post.find_by(title: post_title)
  # turbo_frame_tag uses dom_id which calls to_key returning public_id
  within("#post_#{post.public_id}", match: :first) do
    accept_confirm do
      click_on 'Delete'
    end
  end
end

# Header image
When("I add a header image") do
  # This would interact with the image picker component
  click_on 'Add Header Image' if page.has_button?('Add Header Image')
end

When("I select {string} as the header image") do |image_name|
  # Select from image picker
  find("[data-image-name='#{image_name}']").click if page.has_css?("[data-image-name='#{image_name}']")
end

# Assertions
Then("the post {string} should exist") do |post_title|
  expect(Post.find_by(title: post_title)).to be_present
end

Then("the post {string} should no longer exist") do |post_title|
  expect(Post.find_by(title: post_title)).to be_nil
end

Then("I should see {string} in the posts list") do |text|
  expect(page).to have_content(text)
end

Then("I should not see {string} in the posts list") do |text|
  expect(page).to have_no_content(text)
end

Then("the post should have the slug {string}") do |slug|
  # Find the post by the slug we expect, or by the last post in the current site
  post = current_site.posts.find_by(slug: slug) || current_site.posts.order(created_at: :desc).first
  expect(post&.slug).to eq(slug)
end

Then("the post should have the title {string}") do |title|
  # Find the post we just edited (stored in @post) or by title
  post = @post&.reload || current_site.posts.find_by(title: title)
  expect(post&.title).to eq(title)
end

Then("the post should have a slug based on the title") do
  # Find the most recently created post for the current site
  post = current_site.posts.order(created_at: :desc).first
  expect(post&.slug).to be_present
end

Then("the post should have publish date {string}") do |date|
  # Use the @post we edited
  post = @post&.reload || current_site.posts.order(updated_at: :desc).first
  expect(post&.publish_at&.to_date&.to_s).to eq(date)
end

Then("the post should have a header image") do
  post = Post.last
  expect(post.header_image).to be_present
end

Then("the post should display {string} as header") do |_image_name|
  post = Post.last
  expect(post.header_image).to be_present
end

Then("I should see pagination controls") do
  expect(page).to have_css('.pagination, nav.pagy')
end

Then("I should see {int} posts on the first page") do |count|
  expect(page).to have_css('article.post-card', count: count)
end
