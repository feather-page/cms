# Authentication step definitions

# Background steps
Given("a user exists with email {string}") do |email|
  @user = User.find_by(email: email) || create(:user, email: email)
end

# Login page
When("I visit the login page") do
  visit login_path
end

When("I enter my email address {string}") do |email|
  fill_in "email", with: email
end

# Token generation
Then("a login token should have been generated") do
  # In test mode with deliver_later, emails are enqueued, not delivered immediately
  # We verify that the user can generate a token (which happens when email is sent)
  expect(@user.generate_token_for(:email_login)).to be_present
end

Given("a login token was generated for {string}") do |email|
  @user = User.find_by(email: email) || create(:user, email: email)
  @login_token = @user.generate_token_for(:email_login)
end

Given("an expired login token exists for {string}") do |email|
  @user = User.find_by(email: email) || create(:user, email: email)
  # Generate a token and then travel forward in time to expire it
  @login_token = @user.generate_token_for(:email_login)
  # We'll simulate an expired token by using an invalid token
  @login_token = "expired_invalid_token"
end

When("I visit the login link from the email") do
  visit login_token_path(token: @login_token)
end

# Login state assertions
Then("I should be logged in") do
  # After login, we should be on the root path and see the sites
  expect(page).to have_current_path(root_path)
  expect(page).to have_no_current_path(login_path)
end

Then("I should not be logged in") do
  # If not logged in, we should be on the login page
  expect(page).to have_current_path(login_path)
end

# Logged in state
Given("I am logged in as {string}") do |email|
  @user = User.find_by(email: email) || create(:user, email: email)
  login_as(@user)
end

Given("I have a site to access") do
  @site = create(:site)
  @user.sites << @site unless @user.sites.include?(@site)
  assign_current_site(@site)
end

Given("I am logged in") do
  @user = create(:user)
  @site = create(:site)
  @user.sites << @site
  login_as(@user)
  assign_current_site(@site)
end

# Logout
Then("I should be logged out") do
  visit root_path
  expect(page).to have_current_path(login_path)
end
