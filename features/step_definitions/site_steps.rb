# Site management step definitions

# Site existence
Given("a site {string} exists") do |site_title|
  @site = create(:site, title: site_title)
  current_user.sites << @site unless current_user.sites.include?(@site)
  assign_current_site(@site)
end

Given("I have a site {string}") do |site_title|
  @site = create(:site, title: site_title)
  current_user.sites << @site unless current_user.sites.include?(@site)
  assign_current_site(@site)
end

Given("a site {string} exists that belongs to me") do |site_title|
  @site = create(:site, title: site_title)
  current_user.sites << @site
  assign_current_site(@site)
end

Given("a site {string} exists that belongs to another user") do |site_title|
  other_user = create(:user)
  other_site = create(:site, title: site_title)
  other_user.sites << other_site
end

# Navigation
When("I go to the sites overview") do
  visit root_path
end

When("I edit the site {string}") do |site_title|
  site = Site.find_by(title: site_title)
  visit edit_site_path(site)
end

# Form actions
When("I change the title to {string}") do |new_title|
  fill_in "Title", with: new_title
end

When("I change the emoji to {string}") do |emoji|
  fill_in "Emoji", with: emoji
end

# Assertions
Then("the site {string} should have been created") do |site_title|
  expect(Site.find_by(title: site_title)).to be_present
end

Then("the title {string} should be displayed") do |title|
  expect(page).to have_content(title)
end

Then("the emoji {string} should be displayed") do |emoji|
  # After update, we're on the edit page, so check the input field value
  expect(page).to have_field("Emoji", with: emoji)
end
