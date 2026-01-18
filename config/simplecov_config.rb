require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.lcov_file_name = 'lcov.info'
  c.single_report_path = 'coverage/lcov.info'
end

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
]

SimpleCov.start 'rails' do
  enable_coverage :branch

  add_filter '/spec/'
  add_filter '/features/'
  add_filter '/config/'
  add_filter '/db/'
  add_filter '/vendor/'

  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Components', 'app/components'
  add_group 'Services', 'app/interactions'
  add_group 'Mailers', 'app/mailers'
  add_group 'Jobs', 'app/jobs'
  add_group 'Helpers', 'app/helpers'

  # Track coverage across test suites
  command_name "#{ENV.fetch('TEST_SUITE', 'tests')}-#{Process.pid}"

  # Merge results from different test runs
  use_merging true
  merge_timeout 3600

  # Minimum coverage thresholds
  # Target: 100% - raise these as coverage improves
  minimum_coverage line: 85
end
