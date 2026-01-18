# Common step definitions used across multiple features

# Click actions
When("I click {string}") do |button_text|
  click_on button_text
end

When("I click on {string}") do |link_text|
  click_on link_text
end

# Form actions
When("I fill in {string} with {string}") do |field, value|
  fill_in field, with: value
end

When("I select {string} from {string}") do |value, field|
  select value, from: field
end

When("I check {string}") do |checkbox|
  check checkbox
end

When("I uncheck {string}") do |checkbox|
  uncheck checkbox
end

# Table-based form filling
When("I fill in the following:") do |table|
  table.rows_hash.each do |field, value|
    fill_in field, with: value
  end
end

# Visibility assertions
Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

Then("I should not see {string}") do |text|
  expect(page).to have_no_content(text)
end

Then("I should see {string} in the list") do |text|
  expect(page).to have_content(text)
end

Then("I should not see {string} in the list") do |text|
  expect(page).to have_no_content(text)
end

# Flash messages
Then("I should see a confirmation message") do
  expect(page).to have_css('.alert-success, .notice, [role="alert"]')
end

Then("I should see an error message") do
  expect(page).to have_css('.alert-danger, .alert-error, .error, [role="alert"]')
end

Then("I should see a success message") do
  expect(page).to have_css('.alert-success, .notice, [role="alert"]')
end

# Navigation/Redirect assertions
Then("I should be on the {word} page") do |page_name|
  expected_path = case page_name
                  when 'login' then login_path
                  when 'sites', 'home' then root_path
                  else
                    send("#{page_name}_path")
                  end
  expect(page).to have_current_path(expected_path, ignore_query: true)
end

Then("I should be redirected to the sites overview") do
  expect(page).to have_current_path(root_path, ignore_query: true)
end

Then("I should be redirected to the login page") do
  expect(page).to have_current_path(login_path, ignore_query: true)
end

# Debug helper
Then("I debug") do
  # rubocop:disable Lint/Debugger
  binding.irb
  # rubocop:enable Lint/Debugger
end

Then("I take a screenshot") do
  # rubocop:disable Lint/Debugger
  page.save_screenshot("tmp/screenshot_#{Time.current.to_i}.png")
  # rubocop:enable Lint/Debugger
end
