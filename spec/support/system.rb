require "capybara/cuprite"

Capybara.javascript_driver = :cuprite
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800])
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite
  end

  config.before(:suite) do
    # cleanup capybara screenshots
    FileUtils.rm_rf(Rails.root.glob('tmp/capybara/*'))

    # Cleanup hugo sites
    FileUtils.rm_rf(Rails.root.glob('tmp/hugo/*'))
    FileUtils.rm_rf(Rails.root.glob('tmp/staging_sites/*'))
  end
end
