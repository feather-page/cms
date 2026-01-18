# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop -a"
  step "Style: JavaScript", "yarn lint"

  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-summary --no-pager --exit-on-warn --exit-on-error"

  step "Tests: RSpec", "bin/rails spec"
  step "Tests: Cucumber", "bin/cucumber"
  step "Tests: Jest", "yarn test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  if success?
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
