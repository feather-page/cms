require 'rack_session_access/capybara'

module CucumberHelpers
  def login_as(user)
    @current_user = user

    if Capybara.current_driver == Capybara.javascript_driver
      # For JavaScript tests, use token-based login
      token = user.generate_token_for(:email_login)
      visit login_token_path(token: token)
    else
      # For rack_test, use session manipulation
      page.set_rack_session(user_id: user.id)
    end
  end

  def current_user
    @current_user
  end

  def current_site
    @current_site
  end

  def assign_current_site(site)
    @current_site = site
  end
end

World(CucumberHelpers)
