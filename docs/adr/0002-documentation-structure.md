# Flat documentation structure

Status: accepted (revised 2026-08-28)

Documentation is kept flat and written in English: `CONTEXT.md` at the root holds the domain language,
`AGENTS.md` the working instructions, `docs/adr/` the decisions, and `features/` the executable
specifications. The earlier version of this ADR mandated a nested `docs/` tree with a README index per
level — those indexes went stale and were never fully created, so several were fiction by the time
anyone read them.

## Consequences

`CONTEXT.md` is now a single point that has to be maintained, but there is only one of it. Removed in the
2026-08-28 cleanup: `docs/SUMMARY.md`, `docs/superpowers/` (both still in git history),
`docs/architecture/` (its overview became `CONTEXT.md`), and `docs/features/` (moved to `features/`).
The projects Gherkin file and its implementation plan were dropped too: the feature shipped and is
covered by RSpec, but the scenarios never got step definitions.
