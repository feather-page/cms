# Page management step definitions

# Navigation
When("I go to the pages list for {string}") do |site_title|
  site = Site.find_by(title: site_title)
  visit site_pages_path(site)
end

# Page existence
Given("a page {string} exists for {string}") do |page_title, site_title|
  site = Site.find_by(title: site_title)
  @page = create(:page, title: page_title, site: site, slug: "/#{page_title.parameterize}")
end

Given("{int} pages exist for {string}") do |count, site_title|
  site = Site.find_by(title: site_title)
  count.times do |n|
    create(:page, title: "Page #{n + 1}", site: site, slug: "/page-#{n + 1}")
  end
end

# Form actions
When("I enter the page title {string}") do |title|
  # Wait for form to load
  find('h1', text: /New Page|Edit Page/i, wait: 5)
  fill_in 'page_title', with: title
end

When("I enter the page slug {string}") do |slug|
  fill_in 'page_slug', with: slug
end

When("I change the page title to {string}") do |title|
  # Title field should be visible when editing an existing page
  fill_in 'page_title', with: title
end

# Edit actions
When("I edit the page {string}") do |page_title|
  page_record = Page.find_by(title: page_title)
  visit edit_site_page_path(page_record.site, page_record)
end

# Delete actions
When("I delete the page {string}") do |page_title|
  page_record = Page.find_by(title: page_title)
  # Pages use public_id for turbo frame DOM id
  within("#page_#{page_record.public_id}", match: :first) do
    accept_confirm do
      click_on 'Delete'
    end
  end
end

# Assertions
Then("the page {string} should exist") do |page_title|
  expect(Page.find_by(title: page_title)).to be_present
end

Then("the page {string} should no longer exist") do |page_title|
  expect(Page.find_by(title: page_title)).to be_nil
end

Then("the homepage should exist") do
  expect(current_site.pages.find_by(slug: '/')).to be_present
end

Then("the page should have the title {string}") do |title|
  @page&.reload
  page_record = @page || current_site.pages.find_by(title: title)
  expect(page_record&.title).to eq(title)
end

Then("the page {string} should be in the navigation") do |page_title|
  page_record = Page.find_by(title: page_title)
  expect(page_record.add_to_navigation).to be true
end

Then("I should see {string} in the pages list") do |text|
  expect(page).to have_content(text)
end
