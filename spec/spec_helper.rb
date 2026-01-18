ENV['TEST_SUITE'] = 'rspec'
require File.expand_path('../config/simplecov_config', __dir__)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.raise_errors_for_deprecations!

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
