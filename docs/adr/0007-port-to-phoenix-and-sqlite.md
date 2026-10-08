# Port to Phoenix and SQLite

Status: accepted (2026-10-06, issue #378)

The CMS ran on Rails 8 with Postgres, Solid Queue (a separate job container) and Solid Cable, and
served two private sites as static files. For a one-person project that stack cost more than it
gave: dozens of gems to keep current, a database server and a job worker next to the web process,
and memory and energy for traffic that fits in a single process. The goals were fewer
dependencies, less memory and energy, and one container. We rewrote the app as an idiomatic
Phoenix 1.8 application on SQLite rather than translating Rails idioms one to one.

## Decision

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

## Consequences

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
ExUnit ([0008](0008-behaviour-is-specified-in-exunit.md)), the static site is rendered from EEx
([0005](0005-static-sites-with-erb.md)), and the export Sink kept its shape
([0006](0006-export-writes-through-a-sink.md)).

## Considered options

**A compatibility layer** (reading the Rails schema, or both apps side by side on one database).
Rejected: it would have tied the new schema to the old one (navigations, polymorphic images,
Active Storage tables, integer enums) for the sake of a move that happens once. With two sites, an
hour of frozen editing for dump and import (`docs/cutover.md`) is the cheaper price.
