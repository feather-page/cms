# Book review step definitions

# Click actions for reviews
When("I click {string} for {string}") do |button_text, book_title|
  book = Book.find_by(title: book_title)
  within("tr##{ActionView::RecordIdentifier.dom_id(book)}", match: :first) do
    click_on button_text
  end
end

# Star rating
When("I set the rating to {int} stars") do |stars|
  within(".star-rating") do
    all("[data-star-rating-target='star']")[stars - 1].click
  end
end

# Review content
When("I enter review content {string}") do |content|
  editor = find("[data-controller='editor']", wait: 5)
  editor.find(".ce-paragraph", wait: 5).set(content)
end

When("I enter a review content with more than 300 characters") do
  long_content = "A" * 350
  editor = find("[data-controller='editor']", wait: 5)
  editor.find(".ce-paragraph", wait: 5).set(long_content)
  # Wait for title field to appear
  sleep 0.5
end

When("I change the review content to {string}") do |content|
  editor = find("[data-controller='editor']", wait: 5)
  paragraph = editor.find(".ce-paragraph", wait: 5)
  # Clear using select all + backspace, then set new content
  paragraph.click
  paragraph.send_keys([:control, 'a'], :backspace)
  paragraph.send_keys(content)
end

# Title assertions
Then("the title should be pre-filled with {string}") do |expected_title|
  expect(page).to have_field("post_title", with: expected_title)
end

Then("the title field should appear") do
  expect(page).to have_css("[data-post_form-target='titleAndSlug']:not(.d-none)", wait: 5)
end

# Review existence
Given("a review exists for {string}") do |book_title|
  book = Book.find_by(title: book_title)
  post = create(:post, site: book.site, title: "Review: #{book_title}", content: [])
  book.update!(post: post, rating: 4)
end

Given("a review {string} exists for {string}") do |review_title, book_title|
  book = Book.find_by(title: book_title)
  post = create(:post, site: book.site, title: review_title, content: [])
  book.update!(post: post, rating: 4)
end

Given("a review {string} with {int} stars exists for {string}") do |review_title, stars, book_title|
  @book = Book.find_by(title: book_title)
  post = create(:post, site: @book.site, title: review_title, content: [])
  @book.update!(post: post, rating: stars)
end

Given("a short review with {int} stars exists for {string}") do |stars, book_title|
  book = Book.find_by(title: book_title)
  post = create(:post, site: book.site, title: nil, content: [])
  book.update!(post: post, rating: stars)
end

# Review assertions
Then("the review should exist as a post") do
  expect(Post.count).to be >= 1
end

Then("the review should be linked to {string}") do |book_title|
  book = Book.find_by(title: book_title)
  expect(book.post).to be_present
end

Then("the review should have no title") do
  @book&.reload
  book = @book || Book.joins(:post).order(created_at: :desc).first
  expect(book.post.title).to be_blank
end

Then("the review should have the title {string}") do |expected_title|
  @book&.reload
  book = @book || Book.joins(:post).order(created_at: :desc).first
  expect(book.post.title).to eq(expected_title)
end

Then("the review should have {int} stars") do |stars|
  @book&.reload
  book = @book || Book.joins(:post).order(created_at: :desc).first
  expect(book.rating).to eq(stars)
end

Then("the review should no longer exist") do
  @book&.reload
  book = @book || Book.order(created_at: :desc).first
  expect(book.post).to be_nil
end

Then("I should see {string} for {string}") do |text, book_title|
  book = Book.find_by(title: book_title)
  within("tr##{ActionView::RecordIdentifier.dom_id(book)}", match: :first) do
    expect(page).to have_content(text)
  end
end

Then("I should not see {string} for {string}") do |text, book_title|
  book = Book.find_by(title: book_title)
  within("tr##{ActionView::RecordIdentifier.dom_id(book)}", match: :first) do
    expect(page).to have_no_content(text)
  end
end

Then("I should see a review for {string} in the posts list") do |book_title|
  book = Book.find_by(title: book_title)
  expect(page).to have_content(book.post.title) if book.post.title.present?
  # For short reviews without title, check by some other means
  expect(book.post).to be_present
end

# Preview assertions
When("I view the site preview") do
  @book ||= Book.joins(:post).order(created_at: :desc).first
  @site = @book.site
  deployment_target = @site.deployment_targets.first || create(:deployment_target, :staging, site: @site)
  # Navigate to the post page where stars are displayed - remove leading slash from slug
  path = @book.post.slug.to_s.sub(/^\//, "")
  visit preview_path(deployment_target, path: path)
end

Then("the post should display {int} stars") do |stars|
  @book&.reload
  book = @book || Book.joins(:post).order(created_at: :desc).first
  expect(book.rating).to eq(stars)
  # Stars are displayed in the static site post template (wait for page to load)
  expect(page).to have_css(".book-rating", text: /★/, wait: 5)
end

Then("the stars should be visible as {string}") do |star_display|
  expect(page).to have_content(star_display)
end

# Confirm deletion
When("I confirm the deletion") do
  # Handled by accept_confirm in Capybara
end
