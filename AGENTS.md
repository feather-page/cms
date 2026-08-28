# AGENTS.md

## Read first

`CONTEXT.md` for the domain language, `features/README.md` for what exists, and only the ADRs in
`docs/adr/` that touch the area you are about to change.

## Workflow

Feature-first: write the Gherkin scenario in `features/` and get it confirmed before implementing.
`rake` runs RSpec and Cucumber together; new code arrives tested.

## Conventions

- Everything is written in English — code, Gherkin, docs
- Business logic lives in `app/interactions/` (LightService), not in controllers
- UI is built as ViewComponents, not partials
- Authorisation goes through Pundit policies, always
- Static output is ERB in `app/views/static_site/` — there is no external generator

## Ask first

New dependencies, migrations, changes to authentication/authorisation or the API, and any push, PR or
deployment.

## Agent skills

### Issue tracker

GitHub Issues in `feather-page/cms`, driven through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: `CONTEXT.md` at the root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.
