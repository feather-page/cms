# Code coverage policy

Status: accepted

100% line coverage is the target for new code; 85% is the floor the build enforces
(`minimum_coverage line: 85` in `config/simplecov_config.rb`). The two numbers differ on purpose — a hard
100% gate on a codebase that is not there yet would block every change, while an explicit floor makes the
ratchet visible and movable.

Coverage is merged across RSpec and Cucumber runs. `rake coverage:all` produces the combined report,
`rake coverage:check` fails below the floor. Branch coverage is tracked but not gated.
