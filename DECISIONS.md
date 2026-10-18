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
the files above there are `docs/api/` (the content API: `openapi.yml` and a README) and
`docs/agents/` (how agent skills use the issue tracker and these docs).

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

The decision stands: the CMS renders its static sites itself, with no external generator.
[0015](#0015-sites-choose-a-theme-from-a-fixed-list) replaces the one fixed design with themes a
site chooses from. Since the port to Phoenix ([0007](#0007-port-to-phoenix-and-sqlite)) the
mechanism is different; the paragraphs above describe the Rails app.

- Each theme's templates are EEx files compiled into its module `Feather.StaticSite.Themes.*`
  with `Phoenix.HTML.Engine` (escaped output); shared helpers live in
  `Feather.StaticSite.ThemeHelpers`. Not HEEx: HEEx adds LiveView's `phx-r` root tag attribute,
  which has no place in a static site. Each theme's stylesheet is
  `priv/static_site/themes/<theme>/theme.css`, inlined into every page.
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

### Update (2026-10-18)

No live directory persists between deploys any more
([0019](#0019-a-site-has-one-deployment-target-addressed-by-its-domain)): the `FileSink` directory
is created in `<storage_root>/static_site/`, synced from and discarded after the sync, and the boot
removes what a crashed deploy left there.

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
  Node nor npm is needed. (Superseded for the admin's styling by
  [0013](#0013-the-admin-uses-setzkasten-tailwind-and-daisyui).)
- **Magic-link-only authentication** from `phx.gen.auth` with passwords and registration removed.
  Users come in through an invitation or `mix feather.create_user`. API tokens keep the Rails
  SHA-256 digest format.
- **A one-time move of the data** instead of a compatibility layer: no shared schema, no dual
  writes, no Rails-shaped tables kept for the sake of the move. Ids, public ids and timestamps
  are preserved.

### Consequences

Release, database and images live in one container with one volume (`/data`); there is no
database server and no job container. SQLite has a single writer, so only one app container may
run against the volume (`ops/compose.yml`) and the app does not scale horizontally. Tests that
touch the database run synchronously for the same reason.

Deliberately dropped or changed in the port:

- **Navigations table**: navigation items belong to the site directly (`navigation_items.site_id`);
  the one-navigation-per-site indirection is gone.
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
  working with the move.
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
hour of frozen editing for moving the data is the cheaper price.

### Update (2026-10-09)

The admin editor is ProseMirror now ([0010](#0010-prosemirror-replaces-editorjs)): the vendored
Editor.js builds are removed, and the editor's packages are installed with npm in `assets/`. The
standalone `esbuild` binary still bundles the JavaScript, but Node and `npm ci` are part of the
asset build, the Docker image and CI. The rest of the decision holds.

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
- **Decision:** All ADRs live in `DECISIONS.md` at the root, the older ones moved word for word; the rest of the flat structure of 0002 holds (`CONTEXT.md`, `AGENTS.md`, `docs/api/`, `docs/agents/`).
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

### Update (2026-10-11)

No site notice shows the published changes not yet deployed any more: the deploy control at the
bottom of the sidebar ([0013](#0013-the-admin-uses-setzkasten-tailwind-and-daisyui)) shows how
many of them production does not show yet (`Feather.Publishing.undeployed_count/1`), next to a
Deploy to production button.

### Update (2026-10-17)

Staging and backup targets are gone ([0017](#0017-sites-are-delivered-only-to-external-hosts-by-ftps)):
every deployment target exports the published versions, and only the preview shows the records as
they are. The count of the deploy control also includes the site's own changes.

## 0012. Autosave with a per-block delta sync

Accepted, 2026-10-09

- **Context:** Editor.js wrote the whole document into a hidden form field that a Save button submitted; the prototype showed that a client-owned document with a debounced, idempotent sync keeps typing instant even with a second of latency.
- **Decision:** The editor pushes the block order when it changes and the changed blocks as ProseMirror JSON; the whole record saves automatically, fields that fail validation are not stored, and a counter column rejects a sync based on a stale state.
- **Consequences:** There is no Save button and a new record is created on the first input; when two tabs or members edit the same record, the later one has to reload and there is no merge.

## 0013. The admin uses setzkasten, Tailwind and daisyUI

Accepted (pilot), 2026-10-10

- **Context:** Robert's Phoenix admins (FeatherPage, ziwoas, zipfelfolio, abakus) each grew their own component layer over felt-css, with two dropdowns, three empty states and Bootstrap class names in Elixir; FeatherPage is the pilot for one shared library.
- **Decision:** The admin (`lib/feather_web`) is styled with Tailwind 4 set up as a fresh `phx_new` 1.8.15 does and daisyUI 5 as a Mix dependency (its `packages/bundle` from GitHub, like setzkasten's own CSS through the Mix build path, not vendored into `assets/vendor` as `phx_new` does), plus the shared component library `setzkasten` (components, `zipfel-light`/`zipfel-dark` themes, the design rules of its `guides/design-system.md`: flat pages, cards only for independent objects such as the sites grid, every irreversible delete confirmed in one shared `<dialog>`). felt-css and its CDN link are gone; `assets/css/app.css` keeps only the editor, media picker and bookshelf styles. The static sites and the preview keep their own stylesheet.
- **Consequences:** `setzkasten` is a git dependency on GitHub (`shostakovich/setzkasten`, perhaps hex later), the Tailwind binary joins the asset build, and component changes that other apps should share go into the library; LiveView tests confirm deletes through `FeatherWeb.ConfirmHelpers`, since the dialog runs in the browser.

## 0014. Mascots are three fixed image slots on the site

Accepted, 2026-10-16

- **Context:** The static site theme shows small illustrations of a site's characters in three places (above the footer, at the end of every post, next to the projects title), so each site needs images that belong to the site rather than to a post, page or project.
- **Decision:** A site has three optional foreign keys to images (`footer_mascot_image_id`, `post_end_mascot_image_id`, `projects_mascot_image_id`, `ON DELETE SET NULL`), set only through `Feather.Sites.put_mascot/4` and `remove_mascot/2` from the site settings; the theme falls back to the site's emoji for an empty slot. Three columns are simple and explicit: the templates read `site.footer_mascot_image`, and the nightly image cleanup sees from the references that the images are in use. Rejected: a generic library of site assets (more UI and a lookup by name in the templates for three images) and a naming convention on uploaded images (implicit, and nothing would reference the images).
- **Consequences:** The image cleanup counts mascots as in use and the export copies their variants like other referenced images; a fourth place needs a migration and a slot; webp variants keep the alpha channel, the JPEG variant is flattened.

## 0015. Sites choose a theme from a fixed list

Accepted, 2026-10-16

- **Context:** One shared theme renders every site, but rocu.de needs a theme of its own while zipfelmaus and the other sites keep the current one.
- **Decision:** A site has a `theme` column holding one of a fixed list of themes in code: `feather` (the default, the current theme) and `simple_sidebar` (first used by rocu.de); every site member picks it in the site settings. A theme brings its own templates, CSS and fonts, while block rendering, routes, Gettext, meta tags, feed and sitemap stay shared. The sidebar theme takes its portrait from a new optional image slot on the site (`portrait_image_id`), built like the mascot slots of 0014. Rejected: a domain-to-theme map in the config (invisible in the admin, a deploy for every change) and CSS or templates stored per site in the database (untested and unversioned).
- **Consequences:** A new theme is a code change with its own tests and templates for every page type; the export and the preview render through the site's theme, and the image cleanup counts the portrait as in use.

## 0016. Diagrams are written in D2 and rendered into SVG images at export

Accepted, 2026-10-17

- **Context:** Posts need diagrams, but published sites contain no JavaScript, and a diagram's post body also appears on list pages and in the feed. Mermaid renders only in a browser, through client-side JavaScript or a headless Chromium; its browserless renderers are young reimplementations.
- **Decision:** A `diagram` block holds D2 source, which the export and the preview render with the `d2` binary (TALA layout, MPL-2.0 since v0.9.0) into SVG files referenced by `<img>`, each with a light and a dark D2 theme and cached under the storage root by a hash of source, d2 version and options. Rejected: Mermaid, and inline SVG, which would bloat every list page and lose its styles in feed readers.
- **Consequences:** `d2` is a new runtime binary, copied from the official `d2lang/d2` image into the release image as a pinned stage that Dependabot updates. Diagrams have no clickable links, selectable text or remote icons, and their colours come from D2 themes, not from the site theme.

## 0017. Sites are delivered only to external hosts by FTPS

Accepted, 2026-10-17

- **Context:** Besides production targets on the owners' web hosting, the CMS kept a staging target per site that it served itself (the `internal` rclone provider writing into a directory, a Caddy container with on-demand TLS asking `/api/caddy/check_domain`), backup targets and a `fastmail` WebDAV provider; changes to settings, navigation and social links redeployed staging. Staging duplicated the preview, and the internal hosting was a second web server with its own volume, TLS and attack surface to run.
- **Decision:** Sites are delivered only to external hosts by FTPS (`hetzner_ftps`; SFTP will follow as another provider). Staging and backup targets, the target `type`, the `internal` and `fastmail` providers and the internal Caddy hosting are removed; a migration deletes those targets and drops the column. The preview is addressed by site (`/preview/<site public id>/`), renders live for everyone who may access the site and needs no target. A change to the site itself (settings, images, social media links, navigation) moves the site's `updated_at` and counts once as not deployed in `Feather.Publishing.undeployed_count/1` instead of redeploying staging. Precompression stays: the `.br` and `.gz` files are uploaded with the site for external Caddy servers.
- **Consequences:** A new site has no deployment target until one is created on the console, and nothing shows it on a public address before its first deploy; the production server drops the Caddy container, its volumes and the staging environment variables (`BASE_HOSTNAME_AND_PORT`, `STAGING_SITES_PATH`).

### Update (2026-10-18)

A site has one deployment target, addressed by the site's domain, and the provider `hetzner_ftps`
is called `ftps` ([0019](#0019-a-site-has-one-deployment-target-addressed-by-its-domain)). Besides
the site's own changes, books and deleting or unpublishing a published record now move the site's
`updated_at`.

## 0018. Scheduled posts deploy themselves when they become due

Accepted, 2026-10-18

- **Context:** A post with a future `publish_at` is left out of the export until it is due, and nothing deploys at that moment; after a deploy the deploy panel showed no pending change, so a scheduled post stayed off the live site until someone happened to deploy again.
- **Decision:** A scheduler checks every minute for scheduled posts (`publish_at` after the version's `published_at`) that became due since its last check, or since the last deploy after a restart, and deploys each target last deployed before that `publish_at` and deployed at least once, with one attempt per due post. `Feather.Publishing.undeployed_count/1` counts a post from the later of `published_at` and `publish_at`, once that has passed. Rejected: a timer per post, which every publish, unpublish and restart would have to reset.
- **Consequences:** The CMS deploys without a click for the first time, taking any other published but undeployed change along. A failed scheduled deploy is not retried; it stays visible as a pending change with the Deploy button, and a post goes live up to a minute after its `publish_at`.

## 0019. A site has one deployment target, addressed by its domain

Accepted, 2026-10-18 (issue #435)

- **Context:** Since [0017](#0017-sites-are-delivered-only-to-external-hosts-by-ftps) every target of a site exports the same published versions, so a second target only mirrored the first, and its `public_hostname` duplicated the site's `domain`, which the preview already uses as canonical address. Books, deletions and unpublishing changed the export without a version, so the deploy control kept saying live.
- **Decision:** A site has at most one deployment target (unique on `site_id`), holding only its provider (`hetzner_ftps` renamed to `ftps`, nothing in it is specific to Hetzner) and credentials; its address is the site's `domain`. Changes without a version (books, deleting or unpublishing a published record) move the site's `updated_at`, and a deploy exports into a fresh directory that it syncs and removes.
- **Consequences:** Delivering a site to two hosts at once, e.g. while moving, needs a second site; several book edits count as one pending change; uploading only the changed files would need a manifest of the last deploy, since no export persists.

## 0020. Code blocks are highlighted at export with the chroma binary

Accepted, 2026-10-18

- **Context:** Code blocks need syntax highlighting, and published sites contain no JavaScript, so it has to happen when the export, the preview and the feed render a block. Issue #430 proposed a Go render service for D2 and highlighting, but highlighting reads only text, so it needs no isolation.
- **Decision:** The export runs the `chroma` binary (v2), pinned in the release image like `d2`, on each code block. It caches the HTML by a hash of the Chroma version, lexer and code, and passes only languages from a fixed list. Each site theme styles the token classes with a light and a dark Chroma style. Rejected: Lumis (a NIF that embeds a Wasmtime JIT in the BEAM, and its architecture changed weeks before this decision), Makeup (no lexers for most of the editor's languages), and a separate render service.
- **Consequences:** Chroma is a second runtime binary; Dependabot cannot update it, so version bumps are manual. Feed readers show code without colours, and a language outside the list stays plain.
