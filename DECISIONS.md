# Decisions

## 0001. BDD feature-first development

Superseded by [0008](#0008-behaviour-is-specified-in-exunit), 2026-10-06

Development without an agreed specification produced features that did not match what was asked for, and
no living record of the intended behaviour. We write Gherkin scenarios in `features/` and get them
confirmed before implementing, so the specification is executable and doubles as documentation.

The default `rake` task runs RSpec and Cucumber together; the search path is set in `config/cucumber.yml`.

## 0002. Flat documentation structure

Superseded by [0009](#0009-decisions-live-in-decisionsmd), 2026-10-09

Documentation is kept flat and written in English: `CONTEXT.md` at the root holds the domain language,
`AGENTS.md` the working instructions, `docs/adr/` the decisions, and `features/` the executable
specifications. The earlier version of this ADR mandated a nested `docs/` tree with a README index per
level — those indexes went stale and were never fully created, so several were fiction by the time
anyone read them.

### Consequences

`CONTEXT.md` is now a single point that has to be maintained, but there is only one of it. Removed in the
2026-08-28 cleanup: `docs/SUMMARY.md`, `docs/superpowers/` (both still in git history),
`docs/architecture/` (its overview became `CONTEXT.md`), and `docs/features/` (moved to `features/`).
The projects Gherkin file and its implementation plan were dropped too: the feature shipped and is
covered by RSpec, but the scenarios never got step definitions.

### Update (2026-10-06)

With the port to Phoenix ([0007](#0007-port-to-phoenix-and-sqlite)) `features/` and its index
`features/README.md` are gone: the executable specification is the ExUnit suite in `test/`
([0008](#0008-behaviour-is-specified-in-exunit)). The structure is otherwise unchanged. Next to
the files above there are `docs/api/` (the content API: `openapi.yml` and a README),
`docs/cutover.md` (the one-time runbook for the move from Rails) and `docs/agents/` (how agent
skills use the issue tracker and these docs).

## 0003. Code coverage policy

Deprecated, 2026-10-06: no coverage gate since the Phoenix port

100% line coverage is the target for new code; 85% is the floor the build enforces
(`minimum_coverage line: 85` in `config/simplecov_config.rb`). The two numbers differ on purpose — a hard
100% gate on a codebase that is not there yet would block every change, while an explicit floor makes the
ratchet visible and movable.

Coverage is merged across RSpec and Cucumber runs. `rake coverage:all` produces the combined report,
`rake coverage:check` fails below the floor. Branch coverage is tracked but not gated.

### Update (2026-10-06)

This policy is not in force. The port to Phoenix ([0007](#0007-port-to-phoenix-and-sqlite))
removed SimpleCov, the rake tasks and Cucumber, and no replacement gate was set up: CI
(`.github/workflows/ci.yml`) checks compilation with warnings as errors, formatting, unused
dependencies and the tests, but not coverage.

What remains: `mix test --cover` writes a report to `cover/` (ignored by version control) on
demand; on 2026-10-06 it showed about 91% line coverage in total. Keeping new code tested now
rests on the test-first workflow of [0008](#0008-behaviour-is-specified-in-exunit), not on a
number.
Bringing back a floor (for example `test_coverage: [summary: [threshold: 85]]` in `mix.exs` and
`mix test --cover` in CI) is a new decision and gets a new ADR.

## 0004. Hugo theme feature parity

Superseded by [0005](#0005-static-sites-rendered-with-erb), 2026-08-28

While the CMS shipped multiple Hugo themes (`ink`, `simple_emoji`), every content feature had to be
implemented in all of them before it counted as done, so that switching themes never lost functionality.

The policy made each feature more expensive while the second theme added little value. ADR-0005 removed
Hugo and the themes entirely, which makes this moot. None of the files it referenced still exist; kept as
a record of why the multi-theme era worked the way it did.

## 0005. Static sites rendered with ERB

Accepted, 2026-08-28; updated 2026-10-06: EEx instead of ERB after the Phoenix port

The CMS used Hugo as an external static site generator, which split templating across Go and ERB,
required a build step before any preview, and resisted RSpec testing. Static sites are now rendered
directly with Rails ERB templates: `PreviewsController` renders them live, and `StaticSite::ExportJob`
writes them to files for deployment via rclone.

### Consequences

Multi-theme support is gone — the design is fixed. RSS feed, sitemap and robots.txt are generated in Ruby
(`app/utils/static_site/`). Removed: `app/utils/hugo/`, `app/jobs/hugo/`, `vendor/themes/`,
`app/models/theme.rb`, and the `hugo` binary. Content blocks render through
`Blocks::Renderer::StaticSiteHtml`.

`.github/workflows/rspec.yml` still installs the `hugo` package — a leftover that can be dropped.

### Update (2026-10-06)

The decision stands: the CMS renders its static sites itself, with no external generator and one
fixed design. Since the port to Phoenix ([0007](#0007-port-to-phoenix-and-sqlite)) the
mechanism is different; the paragraphs above describe the Rails app.

- The templates are EEx files in `lib/feather/static_site/templates/`, compiled into
  `Feather.StaticSite.Templates` with `Phoenix.HTML.Engine` (escaped output). Not HEEx: HEEx adds
  LiveView's `phx-r` root tag attribute, which has no place in a static site. The stylesheet is
  `priv/static_site/static_site.css`, inlined into every page.
- `Feather.StaticSite.SiteData` loads everything a site needs up front;
  `Feather.StaticSite.Renderer` then renders pages, the RSS feed, the sitemap and robots.txt from
  that data and `Routes` without touching the database. Content blocks render through `Feather.StaticSite.Blocks`.
- The preview (`FeatherWeb.PreviewController` via `Feather.StaticSite.Preview`) and the export
  (`Feather.StaticSite.Export`, run by `Feather.Publishing.Deploy`) share that renderer, so both
  show the same markup.
- The `hugo` leftover in the CI workflow mentioned above no longer exists; CI is
  `.github/workflows/ci.yml`.

## 0006. Export writes through a Sink

Accepted, 2026-08-28; implemented in Rails, kept in the Phoenix port; updated 2026-10-06

`StaticSite::ExportJob` carries four unrelated concerns in one class — deploy lock and retry,
which content belongs to a site, pagination and artifact rendering, and file IO — and its spec
asserts against the real filesystem, so every example checks "is a file there" instead of "is the
export correct". Now that `StaticSite::Routes` owns the address scheme, the IO can be lifted out:
`StaticSite::Export` renders a site against a **Sink** and the job keeps only job-shaped work.

The Sink contract is two methods and no lifecycle:

- `write(path, content)` — content generated in the process
- `copy(path, from:)` — a file that already exists on disk

Implementations must be thread-safe, because the export writes from four threads via
`ParallelProcessor`. They guarantee nothing about write *order*.

Two implementations:

- `FileSink` creates a fresh temporary directory inside `deployment_target.build_path` — same
  filesystem as `source_dir`, so moving it into place at the end is cheap. It additionally exposes
  `#dir` and `#discard!`, which are implementation-specific and deliberately *not* part of the
  contract.
- `RecordingSink` keeps a Hash for tests. Its `copy` records the source path and never reads the
  bytes, so image variants — up to 25 MB each, times every entry in `Image::Variants` — never enter
  memory. The name says what the object does rather than claiming where bytes live.

`StaticSite::Export.new(site:, routes:, sink:)` takes no `DeploymentTarget`; if it ever does, the
extraction has failed and the coupling has merely moved. The job builds `Routes` and the `FileSink`,
runs the export, precompresses `sink.dir`, replaces `source_dir` with it, deploys, notifies, and
calls `discard!` in the same `ensure` that releases the deploy lock.

### Consequences

The export becomes near-atomic. Today `cleanup` runs `rm_rf(source_dir)` *first*, so a crash
mid-export leaves the deployed directory half-destroyed until the next successful run. Building into
a temporary directory shrinks that window to the `rm_rf` + `mv` at the end. It is not fully atomic —
an interrupt between those two still leaves `source_dir` missing.

`POSTS_PER_PAGE` moves to `PageRenderer`, so `PreviewsController` stops reaching into a job constant.
This anticipates a later step that gives `PreviewsController` and the export a single renderer; doing
it now avoids cementing the constant in `Export`, where it belongs even less.

Specs split three ways: the export assertions run against `RecordingSink` with no IO, a small
`FileSink` spec against `Dir.mktmpdir` covers nested paths, byte-exact copies and encoding, and one
end-to-end example proves the wiring. Tests stop touching `storage/`.

`PrecompressJob` stays an `ActiveJob` that is only ever `perform_now`'d from a single call site.
That was already true and is not addressed here.

Only one non-test implementation of the Sink exists. A `ZipSink` was considered and rejected as a
sink — zipping a built site is a deployment concern, not a way of writing one. The seam therefore
rests on separating the job's four concerns, not on counting adapters.

### Considered options

**Use `Dir.mktmpdir` in the spec and change nothing else.** Cheapest option, and it was the original
motivation: the export was believed to leave empty directories behind. Measured, that is false — the
full suite (988 examples) leaves `storage/hugo` empty, and the directories found there are dev-run
output and pre-ADR-0005 Hugo debris. Rejected because it fixes a symptom that does not exist and
leaves the four concerns entangled.

**Give the Sink a lifecycle — `prepare`, `finalize`, `commit!`.** Rejected: each of these would be
empty in `RecordingSink`. Preparing the directory belongs in `FileSink`'s constructor, precompressing
and moving into place belong to the job, which already owns lock, deploy and notify.

### Update (2026-10-06)

The Rails implementation shipped, and the port to Phoenix ([0007](#0007-port-to-phoenix-and-sqlite))
kept the seam; the text above uses the Rails names. In the Phoenix app:

| Rails | Phoenix |
|-------|---------|
| Sink contract `write(path, content)`, `copy(path, from:)` | behaviour `Feather.StaticSite.Sink`: `write/3`, `copy/3` (`from:` option) |
| `FileSink`, `#dir`, `#discard!` | `Feather.StaticSite.FileSink`: `new/1`, `dir/1`, `discard/1` |
| `RecordingSink` (a Hash) | `Feather.StaticSite.RecordingSink` (an `Agent`, copies kept as `{:copy, source}`) |
| `StaticSite::Export.new(site:, routes:, sink:)` | `Feather.StaticSite.Export.run(site, routes, sink, opts)` |
| `StaticSite::ExportJob` | `Feather.Publishing.Deploy.run/2`, a task under `Feather.TaskSupervisor` |
| `PrecompressJob` | `Feather.StaticSite.Precompress.run/2`, a plain function |
| four threads via `ParallelProcessor` | `Task.async_stream/3`, one task per scheduler by default |
| `PageRenderer::POSTS_PER_PAGE` | `Feather.StaticSite.Renderer.posts_per_page/0` |

The export still takes no deployment target. The builds of a target live in
`<storage_root>/static_site/<target id>/`; the `FileSink` directory is created there and swapped in
as `public/` by two renames, so the live directory is missing only between them. The single
renderer for preview and export that the consequences anticipated now exists
(`Feather.StaticSite.Renderer`). Export tests run against `RecordingSink`
(`test/feather/static_site/export_test.exs`), the `FileSink` has its own small test
(`sinks_and_precompress_test.exs`), and the deploy tests cover the wiring.

## 0007. Port to Phoenix and SQLite

Accepted, 2026-10-06 (issue #378)

The CMS ran on Rails 8 with Postgres, Solid Queue (a separate job container) and Solid Cable, and
served two private sites as static files. For a one-person project that stack cost more than it
gave: dozens of gems to keep current, a database server and a job worker next to the web process,
and memory and energy for traffic that fits in a single process. The goals were fewer
dependencies, less memory and energy, and one container. We rewrote the app as an idiomatic
Phoenix 1.8 application on SQLite rather than translating Rails idioms one to one.

### Decision

- **Contexts and scopes** (`Feather.Accounts`, `Sites`, `Content`, `Books`, `Media`,
  `Publishing`) replace the light-service interactions, models and Pundit policies. Every
  context function takes a `%Feather.Accounts.Scope{}`; a site gets into a scope only through
  `Sites.get_site!/2`, which applies the one authorisation rule (super admin or member).
  Inaccessible records behave like missing ones.
- **LiveView admin** replaces controllers, ERB views, ViewComponent, Turbo and Stimulus. Live
  updates (deploy notices) go through `Phoenix.PubSub`; Action Cable and Solid Cable are gone.
- **SQLite** (`ecto_sqlite3`) replaces Postgres: one database file, WAL journal, immediate
  transactions and a busy timeout (`config/config.exs`), so the single writer waits instead of
  failing. Primary keys are binary UUIDs, URLs use the 12 character `public_id`.
- **Files instead of Active Storage**: `Feather.Media` stores originals and libvips variants
  (`vix`, precompiled) under the storage root and generates the variants on create.
- **OTP instead of a job queue**: deploys run as tasks under `Feather.TaskSupervisor`, waiting
  deploys are coalesced through a `Registry`, the daily image cleanup is a small GenServer
  (`Feather.Media.CleanupScheduler`). A deploy in flight does not survive a restart; stale
  deploy locks are released on boot, so it can simply be started again.
- **felt-css** replaces Bootstrap with Sass: one stylesheet linked from the root layout that
  understands Bootstrap class names, plus a small `assets/css/app.css`. JavaScript (LiveView
  hooks, the vendored Editor.js builds) is bundled by the standalone `esbuild` binary, so neither
  Node nor npm is needed.
- **Magic-link-only authentication** from `phx.gen.auth` with passwords and registration removed.
  Users come in through an invitation or `mix feather.create_user`. API tokens keep the Rails
  SHA-256 digest format.
- **A one-time dump and import** (`mix feather.import`, `Feather.Release.import_dump/2`, see
  `docs/cutover.md`) moves the data instead of a compatibility layer: no shared schema, no dual
  writes, no Rails-shaped tables kept for the sake of the import. Ids, public ids and timestamps
  are preserved.

### Consequences

Release, database and images live in one container with one volume (`/data`); there is no
database server and no job container. SQLite has a single writer, so only one app container may
run against the volume (`ops/compose.yml`) and the app does not scale horizontally. Tests that
touch the database run synchronously for the same reason.

Deliberately dropped or changed in the port:

- **Navigations table**: navigation items belong to the site directly (`navigation_items.site_id`);
  the one-navigation-per-site indirection is gone and the import merges it into the site.
- **Polymorphic images**: `images.imageable_type/imageable_id` became explicit foreign keys.
  `post_id`, `page_id` and `project_id` record which record embeds the image in its content;
  header, thumbnail and cover images are referenced by their owner (`header_image_id`,
  `thumbnail_image_id`, `cover_image_id`).
- **Slug endpoint**: `POST /api/sites/:site_id/slugs`, which the Stimulus slug controller called,
  is gone. The LiveView forms suggest slugs server-side (`Feather.Content`).
- **Content API** (`docs/api/openapi.yml`) is stricter in a few places: an unknown
  `header_image_id` or `thumbnail_image_id` is a 422 instead of being silently cleared, `content`
  that is not an array is a 422 instead of being ignored, and sites the token cannot access answer
  404 (the documented 403 was unreachable). The other direction: plain strings are accepted as list
  item shorthand. The pagination `meta` and the `?p=` parameter, which Rails already had, are now
  documented.
- **Invitations** are signed `Phoenix.Token`s valid for seven days; Rails invitation links stopped
  working at the cutover.
- Smaller things: the Unsplash endpoints of the Rails admin became part of the header image
  picker LiveComponent, the page form has no "created at" field, and the Jekyll importer (`lib/jekyll_importer`, a
  client of the content API) and Lookbook were not ported.

The ADRs written for Rails were revisited in the same change: behaviour is now specified in
ExUnit ([0008](#0008-behaviour-is-specified-in-exunit)), the static site is rendered from EEx
([0005](#0005-static-sites-rendered-with-erb)), and the export Sink kept its shape
([0006](#0006-export-writes-through-a-sink)).

### Considered options

**A compatibility layer** (reading the Rails schema, or both apps side by side on one database).
Rejected: it would have tied the new schema to the old one (navigations, polymorphic images,
Active Storage tables, integer enums) for the sake of a move that happens once. With two sites, an
hour of frozen editing for dump and import (`docs/cutover.md`) is the cheaper price.

## 0008. Behaviour is specified in ExUnit

Accepted, 2026-10-06; supersedes [0001](#0001-bdd-feature-first-development)

ADR-0001 made Gherkin scenarios in `features/` the agreed, executable specification. The intent
holds: no implementation without a confirmed description of the behaviour. The mechanism does
not survive the port to Phoenix ([0007](#0007-port-to-phoenix-and-sqlite)): Cucumber needed
step definitions, a browser driver and a second test runner on top of RSpec, and several
scenarios (projects, for one) never got step definitions at all. We now describe behaviour as
ExUnit tests, written first and confirmed before implementing.

### Workflow

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

### Consequences

The Cucumber scenarios of the Rails app were ported into these tests; the test modules name the
feature file they replace (for example `FeatherWeb.PostLiveTest` for `posts.feature`,
`FeatherWeb.Api.V1.ContentApiTest` for `content_api.feature`). `features/`, its step definitions,
`config/cucumber.yml` and the feature index are gone.

What is lost is a specification a non-developer can read without knowing Elixir. For a
one-person project that reader does not exist; the scenario is confirmed in conversation (or in
the issue) before the test is written.
## 0009. Decisions live in DECISIONS.md

Accepted, 2026-10-09

- **Context:** [0002](#0002-flat-documentation-structure) kept ADRs as separate files in `docs/adr/`; read in order and searched as a whole, one file serves better.
- **Decision:** All ADRs live in `DECISIONS.md` at the root, the older ones moved word for word; the rest of the flat structure of 0002 holds (`CONTEXT.md`, `AGENTS.md`, `docs/api/`, `docs/cutover.md`, `docs/agents/`).
- **Consequences:** ADRs link to each other by anchor instead of file name, and new ones follow the format of the newest entries; `docs/adr/TEMPLATE.md` is gone.

## 0010. ProseMirror replaces Editor.js

Accepted, 2026-10-09

- **Context:** Editor.js has no undo, weak selection across blocks and on mobile, and unevenly maintained plugins (`nested-list` has had no release since 2024); a self-built editor prototype showed that undo, input methods, nested lists and tables would still all be ahead of us.
- **Decision:** ProseMirror (with `prosemirror-history`, `-tables` and `-schema-list`) under our own Notion-style UI in a LiveView hook, installed with npm in `assets/`; content is converted between `Blocks` and ProseMirror JSON on the server.
- **Consequences:** Node and `npm ci` become part of the asset build, Docker image and CI, and Dependabot watches npm; the editor's JavaScript has no browser tests, only ExUnit, LiveViewTest and a manual test on desktop, iOS and Android.

## 0011. Published versions replace the draft flag

Accepted, 2026-10-09

- **Context:** With autosave ([0012](#0012-autosave-with-a-per-block-delta-sync)) every edit is stored at once, so a deploy would ship half-finished changes, and there was no way back to an earlier state.
- **Decision:** A post, page or project holds its unpublished changes; publishing copies all its columns into a version table and points `published_version_id` at the copy, and a record without a published version is a draft, replacing the `draft` column. Production and backup targets export published versions; preview and staging show the records as they are.
- **Consequences:** Every record gets version 1 in a migration and the content API's `draft` changes meaning; there is no history between two publishes except the editor's undo, and publishing does not deploy (a site notice shows published changes not yet deployed).

## 0012. Autosave with a per-block delta sync

Accepted, 2026-10-09

- **Context:** Editor.js wrote the whole document into a hidden form field that a Save button submitted; the prototype showed that a client-owned document with a debounced, idempotent sync keeps typing instant even with a second of latency.
- **Decision:** The editor pushes the block order when it changes and the changed blocks as ProseMirror JSON; the whole record saves automatically, fields that fail validation are not stored, and a counter column rejects a sync based on a stale state.
- **Consequences:** There is no Save button and a new record is created on the first input; when two tabs or members edit the same record, the later one has to reload and there is no merge.
