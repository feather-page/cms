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
the files above there is `docs/agents/` (how agent skills use the issue tracker and these docs).

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

Accepted, 2026-08-28; updated 2026-10-06: EEx instead of ERB after the Phoenix port; updated
2026-10-18: a separate stylesheet ([0021](#0021-exported-sites-link-one-cached-stylesheet))

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
  `priv/static_site/themes/<theme>/theme.css`, inlined into every page (replaced on 2026-10-18 by
  `style.css`, see [0021](#0021-exported-sites-link-one-cached-stylesheet)).
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
  Users come in through an invitation or `mix feather.create_user`.
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
- **Invitations** are signed `Phoenix.Token`s valid for seven days; Rails invitation links stopped
  working with the move.
- Smaller things: the Unsplash endpoints of the Rails admin became part of the header image
  picker LiveComponent, the page form has no "created at" field, and the Jekyll importer
  (`lib/jekyll_importer`) and Lookbook were not ported.

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
- **LiveView and controller tests** in `test/feather_web/` specify what a user does and sees:
  `Phoenix.LiveViewTest` drives forms and buttons by their DOM ids. These take the place of the
  Cucumber scenarios.

Test names read as scenarios ("creating a post with block content"), so the test file stays the
readable record of the intended behaviour.

### Consequences

The Cucumber scenarios of the Rails app were ported into these tests; the test modules name the
feature file they replace (for example `FeatherWeb.PostLiveTest` for `posts.feature`).
`features/`, its step definitions, `config/cucumber.yml` and the feature index are gone.

What is lost is a specification a non-developer can read without knowing Elixir. For a
one-person project that reader does not exist; the scenario is confirmed in conversation (or in
the issue) before the test is written.

## 0009. Decisions live in DECISIONS.md

Accepted, 2026-10-09

- **Context:** [0002](#0002-flat-documentation-structure) kept ADRs as separate files in `docs/adr/`; read in order and searched as a whole, one file serves better.
- **Decision:** All ADRs live in `DECISIONS.md` at the root, the older ones moved word for word; the rest of the flat structure of 0002 holds (`CONTEXT.md`, `AGENTS.md`, `docs/agents/`).
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
- **Consequences:** Every record gets version 1 in a migration; there is no history between two publishes except the editor's undo, and publishing does not deploy (a site notice shows published changes not yet deployed).

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

The sites' current host runs Apache, not Caddy, so the precompressed files went unused (issue
#447). The export now writes an `.htaccess` (`Feather.StaticSite.Htaccess`) that
serves the `.br` or `.gz` copy of a file or directory index when the browser accepts it, with its
content type, `Content-Encoding` and `Vary: Accept-Encoding`, caches `style.css` for a year and sets
`404.html` as the error document. Every rule but the error document is guarded by the modules it
needs (`mod_rewrite` and `mod_headers`), so a host without them serves the files uncompressed. The
host must allow `AllowOverride FileInfo` and `FollowSymLinks` or `SymLinksIfOwnerMatch`; without
them Apache answers 500 or 403 for every path, which no guard can catch.

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

## 0021. Exported sites link one cached stylesheet

Accepted, 2026-10-18 (issue #447); replaces the inlined stylesheet of [0005](#0005-static-sites-rendered-with-erb)'s 2026-10-06 update

- **Context:** Every exported page inlined its theme's font faces and stylesheet (about 26 KB, [0005](#0005-static-sites-rendered-with-erb)), so the CSS made up most of a short page and no browser could cache it.
- **Decision:** The export writes the font faces and the theme's stylesheet as one `style.css` at the site root, a generated file next to `feed.xml`, and every page links it as `style.css?v=<first 12 hex digits of its SHA-256>`; the preview serves the same file. The `.htaccess` lets browsers cache it for a year as `immutable` ([0017](#0017-sites-are-delivered-only-to-external-hosts-by-ftps)), and the hash makes them fetch a changed stylesheet at once. The font preload stays. Rejected: splitting the stylesheet by the blocks a site uses, which saves about 1.5 KB gzipped per visit once the stylesheet is cached.
- **Consequences:** A first visit makes one more request, once per site. The year-long cache comes from the `.htaccess`, so a host other than Apache needs its own rules for it; without them browsers revalidate `style.css` like any other file.

## 0022. Exported pages are formatted with lazy_html

Accepted, 2026-10-18 (issue #448)

- **Context:** The source of exported pages looked generated: a quarter to a third of the lines were blank, the indentation restarted at column 0 in every partial, block content ran on one line and empty elements were written both with and without a closing slash.
- **Decision:** `Feather.StaticSite.HTMLFormatter` runs as the last step of rendering a page, so the preview and the export show the same markup; the feed, the sitemap and `style.css` are not formatted. It parses the page with lazy_html (lexbor, which builds the tree a browser builds), moved from a test-only dependency into the release, and writes the tree back with the HTML serialisation's escaping: block elements on their own lines, indented two spaces per level, no blank lines, no closing slash on empty HTML elements, no comments. Whitespace changes only next to block elements, where browsers ignore it; raw text and `pre`/`textarea` content render unchanged. Rejected: Floki, already in the release, whose default parser does not build the browser's tree; fixing the whitespace in the EEx templates, which leaves the blocks' output on one line.
- **Consequences:** The release carries one more NIF (lazy_html, precompiled, needs `libstdc++`). Which tags count as block elements is a list in the formatter: a theme that makes a block element inline in CSS, or gives an element `white-space: pre` other than through these tags, has to be checked with before/after screenshots, as `.bio` (`pre-line`) relies on its text being kept. lexbor 0.1.13 drops the letters after `</` inside a script when they start an end tag (`"</scr"` becomes `"</"`); no page has an inline script today.

## 0023. Books are searched on Hardcover, OpenLibrary without a token

Accepted, 2026-10-19 (issue #451)

- **Context:** In a sample of 30 books searched by title, OpenLibrary found the right book for 20, dropped the connection for 5 and returned no ISBN; Hardcover found 25, 24 with a cover and 23 with an ISBN. Hardcover's API needs a personal token, is in beta and may reset tokens without notice.
- **Decision:** With `HARDCOVER_TOKEN` set, the book search asks Hardcover's GraphQL API from the server; without it, it asks OpenLibrary. Errors are shown, never answered from the other service. Rejected: falling back to OpenLibrary on Hardcover errors, which would hide an expired token and double the wait.
- **Consequences:** Two search clients to maintain. An expired or reset token breaks the search until a new one is set, and the token acts as its owner's Hardcover account. All members of an instance share its rate limit (60 requests a minute on the free plan).

## 0024. Image variants follow the theme's image roles

Accepted, 2026-10-19 (issue #453)

- **Context:** Every image got the same six variants (430 to 2000 px, a 1000 px JPEG), whatever it was used for: a 28 px book cover loaded a 430 px file, a 240 px thumbnail had 2000 px variants nobody loaded, and nothing sat between 430 and 860 px. Images and fonts were sent without a cache header. The inventory of where exported pages show images is on the issue.
- **Decision:** An image's roles follow from what references it, in records as they are and as published (content block, header, thumbnail, homepage header, project header and thumbnail, book cover, portrait, each mascot, and the sharing image that `og:image` links). Each theme declares the sizes every role gets (`image_variants/0`); an image gets the union of its roles' sets, the admin preview (480 px webp) and, as a sharing image, a 1200 px JPEG. Variants fit within N×N and are named after their box (`640.webp`, `1200.jpg`), so a name always means the same file and the `.htaccess` caches images and fonts for a year as `immutable`; font URLs carry a content hash like `style.css` ([0021](#0021-exported-sites-link-one-cached-stylesheet)). Uploads get their role's variants; the export and the preview generate a missing one from the original; on start, after the migrations, and when a site changes its theme, every image's stored variants are brought in line (missing ones added, unneeded ones deleted). Content images drop the `<picture>` JPEG fallback. Rejected: one fixed ladder for all roles (the old way, too large for small roles and too coarse for columns) and generating variants only at export (the preview and the admin would wait on libvips).
- **Consequences:** A new role or a changed theme layout means new sizes in the theme and a restart to backfill. The first start after this change rewrites every image's variants once. Small images collapse sizes they are too small for into the smallest one of the same width, so srcset never lists two equal widths.

## 0025. Redirects share the URL space with slugs and are exported as .htaccess rules

Accepted, 2026-10-20

- **Context:** Sites rename posts after publishing and carry URLs from earlier blog engines that still get visits. The CMS only uploads files ([0017](#0017-sites-are-delivered-only-to-external-hosts-by-ftps)), so it cannot configure a web server, and the sites' host runs Apache.
- **Decision:** Redirects are stored per site, permanent or temporary, from an old path to a post, page or project, or to a path the export generates (`/`, `/feed.xml`), and the export writes them as rewrite rules into the `.htaccess`. Old paths share the site's URL space with slugs and targets reference records, so a URL belongs to content or to one redirect and chains or loops cannot arise; publishing a record whose URL changed stores a redirect from the old URL. Rejected: meta refresh pages at the old paths for every host (status 200, HTML only) and deriving automatic redirects from the version history (they could not be edited or deleted).
- **Consequences:** Hosts other than Apache get no redirects until they get their own mechanism, such as edge rules set over the Bunny API or a Caddy snippet the server imports and reloads after each deploy. A slug whose URL a redirect occupies is refused until the redirect is deleted.

## 0026. Suggestions come from a self-hosted model, made in the CMS, never at export

Accepted, 2026-10-21

- **Context:** Alt texts, descriptions and titles of short posts are rarely written by hand, so images go out with `alt=""` and search results show the truncated first sentence. A self-hosted Ollama instance runs a Gemma 4 model that reads images (`OLLAMA_MODEL`, by default `gemma4:26b-a4b-it-qat`) and holds one model in memory at a time.
- **Decision:** `Feather.Ollama` asks that model over `OLLAMA_URL` with `Req`: an image's alt text after upload or import, in the background; a post's or page's description when it is published or on "Suggest"; a short post's slug and meta title at its first publish. Results are stored on the record, can be overwritten, and a generated description is renewed at publish while it is unedited and the content changed. Rejected: Claude Haiku (better and faster, but drafts leave the house) and generating at export (exports would stop being reproducible and wait on the model).
- **Consequences:** Without `OLLAMA_URL` or with the model down, fields stay empty and the export falls back to excerpts as before. Publishing waits up to 90 seconds for the model, and the CMS queues behind other clients of the same instance.

## 0027. Deploys notify IndexNow and archive.org

Accepted, 2026-10-21

- **Context:** Search engines and the Wayback Machine find new posts only when they next crawl. Google has no notification API for ordinary pages (the sitemap ping is gone, the Indexing API is limited to job postings and livestreams), but Bing, whose index also feeds ChatGPT and Copilot search, and the other IndexNow engines take one.
- **Decision:** After a successful deploy, in the background, the CMS sends the home page and every post, page and project published or changed since the previous deploy to `api.indexnow.org`, for every site, with a key file the export writes per site; and to archive.org's Save Page Now 2, one URL after another, for sites whose members entered archive.org keys in the site settings (encrypted like the deployment target's credentials). Failures are only logged.
- **Consequences:** Every site's public URLs are shared with all IndexNow engines, Yandex included, and archive.org keeps copies until their owner asks for removal. "Changed" relies on the published versions' times, so the sitemap's `lastmod` must come from them too.

## 0028. Favicons and share cards are rendered with libvips at export

Accepted, 2026-10-21

- **Context:** Search results show only favicons served as files, while sites declare their emoji as a `data:` SVG. Pages without an image have no `og:image`, so links to them, short posts above all, are shared without a preview.
- **Decision:** The export renders the site's emoji into a PNG favicon and, for pages without an image, a share card with the title and emoji in the theme's look, both with libvips (already used for image variants) and Noto Color Emoji installed in the Docker image. Pages with their own emoji keep it as an inline icon. Rejected: an uploaded favicon (one more thing to maintain per site) and the portrait as the only fallback (most sites have none).
- **Consequences:** The Docker image grows by the emoji font, and emoji rendering depends on the libvips and Pango versions it ships. Cards are generated images that each theme has to design and that are cached like other variants.

## 0029. Exported sites send security headers from the .htaccess

Accepted, 2026-10-21 (issue #470)

- **Context:** A scan of an exported site found none of the headers that make browsers protect visitors: HSTS, nosniff, a referrer policy, a content security policy. The CMS only uploads files ([0017](#0017-sites-are-delivered-only-to-external-hosts-by-ftps)), so the `.htaccess` is the one place to set them, as for redirects ([0025](#0025-redirects-share-the-url-space-with-slugs-and-are-exported-as-htaccess-rules)). The themes run no scripts ([0016](#0016-diagrams-are-written-in-d2-and-rendered-into-svg-images-at-export), [0020](#0020-code-blocks-are-highlighted-at-export-with-the-chroma-binary)); their structured data is a JSON-LD data block (`<script type="application/ld+json">`), which browsers do not execute. They load nothing from other hosts but embeds.
- **Decision:** The `.htaccess` sets four headers on every response, error pages and redirects included, in a guard for mod_headers, the same for every site: HSTS for a year, without `includeSubDomains` and `preload` because a site's domain may have subdomains the CMS does not serve; `nosniff`; the referrer policy `strict-origin-when-cross-origin`; and a content security policy that allows nothing by default and then only the site's own images (the favicon drawn at export among them, [0028](#0028-favicons-and-share-cards-are-rendered-with-libvips-at-export), plus data URIs for the icon of a page with an emoji of its own), stylesheet and fonts, inline style attributes (the feather theme's hue, the aspect ratio of embeds) and HTTPS frames for embeds, with no scripts (JSON-LD data blocks are not subject to `script-src`), no base URI changes, no form targets and no framing by other sites. Diagram SVGs get a policy of their own that allows their inline styles and their fonts and icons as data URIs and keeps out framing by other sites, since Firefox applies an SVG's own policy even where a page shows it as an image. Rejected: the deprecated headers (X-XSS-Protection, Expect-CT, Public-Key-Pins, Feature-Policy) and the cross-origin isolation headers, since a resource policy could stop feed readers from loading images.
- **Consequences:** Themes stay free of executable scripts (JSON-LD data blocks are their only script elements), style elements and files from other hosts; a test checks every exported page of both themes against the policy, and a theme that needs more has to widen it for every site. Browsers without `style-src-attr` (Firefox before 108, Safari before 15.4) block the inline style attributes. Hosts other than Apache send none of the headers. A domain that drops HTTPS stays unreachable for a year for browsers that visited it.

## 0030. Exported sites invite AI agents

Accepted, 2026-10-21 (issue #469)

- **Context:** A scan of an exported site rated it "not ready" for AI agents: `robots.txt` said nothing about how the content may be used, an agent had to dig a post's text out of the theme's markup (navigation, sidebar, footer), and nothing listed the site's pages for language models. The CMS only uploads files ([0017](#0017-sites-are-delivered-only-to-external-hosts-by-ftps)), so the `.htaccess` is the one place for server rules, as for redirects ([0025](#0025-redirects-share-the-url-space-with-slugs-and-are-exported-as-htaccess-rules)) and security headers ([0029](#0029-exported-sites-send-security-headers-from-the-htaccess)).
- **Decision:** Exported sites invite agents, the same for every site and fixed in code. `robots.txt` allows every use with `Content-Signal: search=yes, ai-input=yes, ai-train=yes`. Every post, page and project gets a Markdown alternate (`Feather.StaticSite.MarkdownAlternate`), written as `index.md` next to its `index.html` and precompressed like it: YAML front matter, the title (a short post's meta title, as in the page's `<title>`) and the content, with absolute canonical URLs. The `.htaccess` serves it at the page's URL whenever the request's `Accept` header names `text/markdown`, whatever else it lists (browsers never ask for it), with `Vary: Accept` and UTF-8 `text/markdown`, in guards for mod_rewrite and mod_headers; the page links it in its head as `rel="alternate"`, and the preview serves it. An `llms.txt` at the site root lists the Markdown alternates. The Markdown renderer sits next to the HTML block renderer, like the feed and the sitemap, and renders the blocks itself; `Feather.Content.HTML`, which owns the tokenizer and the allow list, converts inline HTML to Markdown. Rejected: a format parameter in the HTML block renderer and a renderer behaviour shared by both formats (no caller picks the format at runtime), and `robots.txt` entries per AI bot.
- **Consequences:** Every block type renders twice; a test renders each known type in both formats, so a new type cannot be forgotten in one. Markdown alternates have no highlighting and show diagrams as their D2 source. Hosts other than Apache serve them only at their own paths. The home page's alternate holds the homepage content and all posts without pagination, so it grows with the site; the further pages of the post list get none. `llms.txt` links the alternates of all pages, posts and projects under their titles and with the description of each page's meta tags (the stored description of [0026](#0026-suggestions-come-from-a-self-hosted-model-made-in-the-cms-never-at-export), else the start of the text), and is served as UTF-8 text; like the alternates, it is a path no slug or redirect can take. A redirect from an old path without an extension sends that path's `index.md`, which `llms.txt` and the page's head advertised, to its target's alternate (or to the target if it has none), on Apache and in the preview. No redirect leads to the alternate of a post, page or project, since the alternate moves with its record and targets stay on records so that chains cannot arise ([0025](#0025-redirects-share-the-url-space-with-slugs-and-are-exported-as-htaccess-rules)); `/index.md` stays a target like `/feed.xml`.

## 0031. Agents edit content through an MCP server in the CMS

Accepted, 2026-10-23 (issue #480)

- **Context:** Members want to add books and write posts and pages from Claude (web, desktop, phone, Claude Code) and other agents, whose connectors take remote MCP servers with OAuth. MCP 2026-07-28 made the protocol stateless while clients still roll it out, and the Elixir MCP libraries are pre-1.0 and barely cover that revision.
- **Decision:** The CMS serves MCP at `/mcp` itself, tools only, as JSON responses without SSE or sessions, for 2026-07-28 and for the `initialize` handshake of 2025-11-25; the tools call the contexts, reach only the sites the user is a member of and delete nothing. Rejected: an MCP library, and a REST API next to MCP, which no client needs.
- **Consequences:** We follow protocol revisions by hand. Deleting, projects, redirects, site settings, uploading own photos and super admin access to other sites stay in the admin; content goes in as JSON blocks, whose only schema is `Feather.Content.BlockValidator`.

## 0032. The CMS is its own OAuth server, clients register by metadata document

Accepted, 2026-10-23 (issue #480)

- **Context:** MCP clients authorize with OAuth 2.1, members exist only in the CMS and log in by magic link. MCP 2026-07-28 deprecates Dynamic Client Registration in favour of Client ID Metadata Documents, which Claude and ChatGPT support.
- **Decision:** The CMS issues the tokens: authorization code with PKCE (S256) after the magic-link login and a consent page, opaque tokens bound to `/mcp` and stored as SHA-256 digests, access tokens for an hour, rotating refresh tokens, connections that expire after 90 days unused and can be revoked in the user settings; clients register only by a metadata document, fetched after the login. Rejected: an external identity provider and Dynamic Client Registration.
- **Consequences:** OAuth security is ours to get right and test, and clients without a metadata document cannot connect. The CMS fetches a URL a client names, so only logged-in members can trigger it, over HTTPS with a timeout and a size limit.

## 0033. A site's fediverse identity lives on its domain

Accepted, 2026-10-23 (issue #487)

- **Context:** Sites that moved here from micro.blog lost the fediverse account micro.blog ran on their domain: the handle no longer resolves, and the servers of their followers still know the account at its old address on the domain. micro.blog serves the accounts of custom domains at `/activitypub/<name>` on the domain. The CMS only uploads files to the sites' hosts ([0017](#0017-sites-are-delivered-only-to-external-hosts-by-ftps)), and those run Apache.
- **Decision:** The fediverse identity of a site lives on its domain, at micro.blog's address scheme. A site with a fediverse name is the account `@<name>@<domain>`. The static export writes the account and its objects under addresses that never change with slugs: the WebFinger answer as one static file that answers every query for the domain, the account at `/activitypub/<name>` with the site's title, bio and portrait and the public half of an RSA key pair (2048 bits, generated with OTP; the private half is stored encrypted and never leaves the CMS), its outbox and a document per post at `/activitypub/posts/<public id>`. The `.htaccess` serves them, precompressed copies included, as `application/activity+json`; every page with a document links it as `rel="alternate"`. The CMS runs only the inbox, on its public host under `/fediverse/inbox/`, and the delivery; deliveries follow from comparing each deploy with the federated objects. Whoever controls the hosting controls the account. Rejected: the account on the CMS's host, which ties followers to the CMS as they were tied to micro.blog; content negotiation on page URLs; uploading single files outside the deploy, which races with the sync; Oban for the delivery queue.
- **Consequences:** The account exists only once a deploy has put it online; the CMS records when it first did, follows and deliveries wait for that, and the name is fixed from then on. A site from micro.blog takes over its old account with a new key. Rotating the key in the site settings gives the account a new pair that waits for the next successful deploy to publish its public half; only then does the CMS sign with it and discard the old pair, so servers that fetch the account find the key that signs. A post back on the site after the `Delete` of its document went out comes back under a new address, since servers keep the old one deleted. Changing the domain starts the account over at its new address, online with the next deploy: it loses its followers and the accounts it follows. `activitypub/` and the WebFinger answer are paths no slug or redirect can take, and the names the documents take below `activitypub/` (`outbox`, `posts`, `replies`, `followers`, `following`) cannot be fediverse names. Hosts other than Apache serve the documents without their content type, and fediverse servers reach the inbox only where a proxy in front of the CMS lets them.

## 0034. Replies appear on the site only after a member approves them

Accepted, 2026-10-23 (issue #487)

- **Context:** Readers in the fediverse reply to a site's posts from their own servers, and the replies reach the site's inbox on the CMS ([0033](#0033-a-sites-fediverse-identity-lives-on-its-domain)). Anyone can send one, so showing them as they come would let anyone put text and pictures on the site. The site's content security policy allows only its own images ([0029](#0029-exported-sites-send-security-headers-from-the-htaccess)).
- **Decision:** Replies appear on the site only after a member approves them, as the approved snapshot. A reply to a post waits in Mentions until a member approves or hides it; only replies addressed to the public can be approved. Approving keeps the text and its author's name, handle and picture as the member saw them in Mentions, where the picture loads through the CMS; a reply or author that changed since is not approved. The picture is downloaded through the checked requests: only JPEG, PNG, WebP and GIF by their magic bytes, opened only by that format's own libvips loader (never one libvips picks, so none of its untrusted loaders), refused above 4096 × 4096 pixels by its header, first frame only, kept as one small webp under a name the CMS generates, which the export writes beside the site's images. Both themes show the approved replies in a thread below the post, their links marked `nofollow ugc noopener`, attachments left out, and every post of a site with a fediverse name says how to reply. The author's edit puts a reply back to waiting; their deletion removes it and leaves a tombstone, so that a late `Create` cannot bring it back. The picture of a reply that leaves the site is deleted after the next successful deploy, so that a deploy already running still finds it. Approving, hiding an approved reply and a deletion start a deploy. Rejected: showing replies automatically with a way to hide them; showing only a count with links.
- **Consequences:** Nothing reaches the site without a member. An approved reply stays as approved: a changed profile of its author shows only with the next approval, and an edited reply stays online until the next deploy, unless the edit made it no longer public, which takes it off at once. A deploy that only changes replies changes no post, so it reports nothing to IndexNow and archive.org. Replies and the line on replying appear only on the HTML page, not in the Markdown alternate, the feed or `llms.txt`. Backups keep a deleted reply until they age out.
