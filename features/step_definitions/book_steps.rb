# Book catalog step definitions

# Navigation
When("I go to the books page for {string}") do |site_title|
  site = Site.find_by(title: site_title)
  visit site_books_path(site)
end

# Book existence
Given("a book {string} exists for {string}") do |book_title, site_title|
  site = Site.find_by(title: site_title)
  @book = create(:book, title: book_title, site: site, author: "Test Author")
end

# Form actions
When("I enter the book title {string}") do |title|
  # Wait for form to load
  find('h1', text: /New Book|Edit Book/i, wait: 5) rescue nil
  fill_in 'book_title', with: title
end

When("I enter the author {string}") do |author|
  fill_in 'book_author', with: author
end

When("I set the reading status to {string}") do |status|
  select status, from: 'book_reading_status'
end

# Edit actions
When("I edit the book {string}") do |book_title|
  book = Book.find_by(title: book_title)
  visit edit_book_path(book)
end

# Delete actions
When("I delete the book {string}") do |book_title|
  book = Book.find_by(title: book_title)
  # Books use UUID, dom_id generates book_<uuid>
  within("#book_#{book.id}", match: :first) do
    accept_confirm do
      click_on 'Delete', match: :first
    end
  end
end

# Assertions
Then("the book {string} should exist") do |book_title|
  expect(Book.find_by(title: book_title)).to be_present
end

Then("the book {string} should no longer exist") do |book_title|
  expect(Book.find_by(title: book_title)).to be_nil
end

Then("the book should be marked as {string}") do |status|
  @book&.reload
  book = @book || Book.order(created_at: :desc).first
  expected_status = case status
                    when 'Want to Read' then 'want_to_read'
                    when 'Currently Reading' then 'reading'
                    when 'Finished' then 'finished'
                    else status.downcase.tr(' ', '_')
                    end
  expect(book.reading_status).to eq(expected_status)
end
