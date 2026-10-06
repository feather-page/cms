# Behaviour is specified in ExUnit

Status: accepted (2026-10-06), supersedes [0001](0001-bdd-feature-first-development.md)

ADR-0001 made Gherkin scenarios in `features/` the agreed, executable specification. The intent
holds: no implementation without a confirmed description of the behaviour. The mechanism does
not survive the port to Phoenix ([0007](0007-port-to-phoenix-and-sqlite.md)): Cucumber needed
step definitions, a browser driver and a second test runner on top of RSpec, and several
scenarios (projects, for one) never got step definitions at all. We now describe behaviour as
ExUnit tests, written first and confirmed before implementing.

## Workflow

1. Describe the behaviour as one or more ExUnit tests and get the scenario confirmed.
2. Implement until the tests pass; new code arrives tested.
3. `mix precommit` (compile with warnings as errors, format, test) passes before the work is done.

Where a test goes depends on what it specifies:

- **Context tests** in `test/feather/` specify domain rules through the public context functions
  (`Feather.Content`, `Feather.Sites`, ...): validations, authorisation through the scope, what a
  static export contains (against a `RecordingSink`).
- **LiveView and controller tests** in `test/feather_web/` specify what a user or API client
  does and sees: `Phoenix.LiveViewTest` drives forms and buttons by their DOM ids; API tests check
  responses against `docs/api/openapi.yml`. These take the place of the Cucumber scenarios.

Test names read as scenarios ("creating a post with block content"), so the test file stays the
readable record of the intended behaviour.

## Consequences

The Cucumber scenarios of the Rails app were ported into these tests; the test modules name the
feature file they replace (for example `FeatherWeb.PostLiveTest` for `posts.feature`,
`FeatherWeb.Api.V1.ContentApiTest` for `content_api.feature`). `features/`, its step definitions,
`config/cucumber.yml` and the feature index are gone.

What is lost is a specification a non-developer can read without knowing Elixir. For a
one-person project that reader does not exist; the scenario is confirmed in conversation (or in
the issue) before the test is written.
