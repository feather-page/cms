namespace :coverage do
  desc "Run all tests and report combined coverage"
  task all: :environment do
    require "fileutils"
    FileUtils.rm_rf("coverage")

    rspec_success = run_rspec
    cucumber_success = run_cucumber
    print_coverage_report

    exit(1) unless rspec_success && cucumber_success
  end

  desc "Check if coverage meets minimum threshold"
  task check: :environment do
    validate_coverage_data!
    check_minimum_coverage
  end
end

def run_rspec
  puts "\n#{'=' * 60}\nRunning RSpec...\n#{'=' * 60}"
  system("bundle exec rspec")
end

def run_cucumber
  puts "\n#{'=' * 60}\nRunning Cucumber...\n#{'=' * 60}"
  system('bundle exec cucumber --tags "not @javascript"')
end

def print_coverage_report
  puts "\n#{'=' * 60}\nCoverage Report\n#{'=' * 60}"
  return puts "No coverage report generated" unless File.exist?("coverage/index.html")

  puts "View detailed report: coverage/index.html"
  print_coverage_percentages if File.exist?("coverage/.last_run.json")
  puts "\n#{'=' * 60}"
end

def print_coverage_percentages
  data = JSON.parse(File.read("coverage/.last_run.json"))
  line = data.dig("result", "line")
  branch = data.dig("result", "branch")

  puts "\n  Line Coverage:   #{line&.round(2)}%"
  puts "  Branch Coverage: #{branch&.round(2)}%" if branch
  puts "\n  Target: 100%"
  puts "\n  Run `open coverage/index.html` to see uncovered lines" if line && line < 100
end

def validate_coverage_data!
  return if File.exist?("coverage/.last_run.json")

  puts "No coverage data found. Run `rake coverage:all` first."
  exit(1)
end

def check_minimum_coverage
  data = JSON.parse(File.read("coverage/.last_run.json"))
  line_coverage = data.dig("result", "line") || 0

  if line_coverage < 85
    puts "Coverage #{line_coverage.round(2)}% is below minimum threshold of 85%"
    exit(1)
  else
    puts "Coverage: #{line_coverage.round(2)}% ✓"
  end
end

desc "Run all tests with coverage"
task coverage: "coverage:all"
