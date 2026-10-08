# Code coverage policy

Status: deprecated (2026-10-06): no coverage gate since the Phoenix port

100% line coverage is the target for new code; 85% is the floor the build enforces
(`minimum_coverage line: 85` in `config/simplecov_config.rb`). The two numbers differ on purpose — a hard
100% gate on a codebase that is not there yet would block every change, while an explicit floor makes the
ratchet visible and movable.

Coverage is merged across RSpec and Cucumber runs. `rake coverage:all` produces the combined report,
`rake coverage:check` fails below the floor. Branch coverage is tracked but not gated.

## Update (2026-10-06)

This policy is not in force. The port to Phoenix ([0007](0007-port-to-phoenix-and-sqlite.md))
removed SimpleCov, the rake tasks and Cucumber, and no replacement gate was set up: CI
(`.github/workflows/ci.yml`) checks compilation with warnings as errors, formatting, unused
dependencies and the tests, but not coverage.

What remains: `mix test --cover` writes a report to `cover/` (ignored by version control) on
demand; on 2026-10-06 it showed about 91% line coverage in total. Keeping new code tested now
rests on the test-first workflow of [0008](0008-behaviour-is-specified-in-exunit.md), not on a
number.
Bringing back a floor (for example `test_coverage: [summary: [threshold: 85]]` in `mix.exs` and
`mix test --cover` in CI) is a new decision and gets a new ADR.
