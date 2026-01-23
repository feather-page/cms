# Book block step definitions for EditorJS

# Add book block to editor
When("I add a book block") do
  editor = find("[data-controller='editor']", wait: 5)

  # Click on the editor to focus it
  editor.find(".ce-paragraph", wait: 5).click

  # Open the block toolbox by clicking the plus button
  find(".ce-toolbar__plus", wait: 5).click

  # Wait for popover to open and click on Book tool
  within(".ce-popover--opened", wait: 5) do
    find(".ce-popover-item__title", text: "Book", wait: 5).click
  end
end

# Recent books assertion
Then("I should see the book search with recent books") do
  expect(page).to have_css(".book-tool__search-input", wait: 5)
  expect(page).to have_css(".book-tool__results .list-group-item", wait: 5)
end

# Search in book block
When("I search for {string} in the book block") do |query|
  find(".book-tool__search-input", wait: 5).set(query)
  # Wait for debounced search
  sleep 0.5
end

# Book results assertion
Then("I should see {string} in the book results") do |book_title|
  expect(page).to have_css(".book-tool__results", text: book_title, wait: 5)
end

# Select book from results
When("I select the book {string}") do |book_title|
  within(".book-tool__results", wait: 5) do
    find(".list-group-item", text: book_title, wait: 5).click
  end
end

# Book preview assertion
Then("I should see the book preview for {string}") do |book_title|
  expect(page).to have_css(".book-tool__preview", text: book_title, wait: 5)
end

# Change book button
When("I click {string} in the book block") do |button_text|
  within(".book-tool", wait: 5) do
    click_on button_text
  end
end

# Wait for editor to save (debounced)
When("I wait for the editor to save") do
  sleep 0.5
end

# Post contains book block assertion
Then("the post should contain a book block for {string}") do |book_title|
  book = Book.find_by(title: book_title)
  post = Post.order(created_at: :desc).first

  book_block = post.content.find { |block| block["type"] == "book" }
  expect(book_block).to be_present, "Expected post to contain a book block, but content was: #{post.content.inspect}"
  # The book block stores book_public_id directly in the block (after processing by Blocks::Book)
  expect(book_block["book_public_id"]).to eq(book.public_id)
end
