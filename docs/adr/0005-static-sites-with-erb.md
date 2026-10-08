# Static sites rendered with ERB

Status: accepted (updated 2026-10-06: EEx instead of ERB after the Phoenix port)

The CMS used Hugo as an external static site generator, which split templating across Go and ERB,
required a build step before any preview, and resisted RSpec testing. Static sites are now rendered
directly with Rails ERB templates: `PreviewsController` renders them live, and `StaticSite::ExportJob`
writes them to files for deployment via rclone.

## Consequences

Multi-theme support is gone — the design is fixed. RSS feed, sitemap and robots.txt are generated in Ruby
(`app/utils/static_site/`). Removed: `app/utils/hugo/`, `app/jobs/hugo/`, `vendor/themes/`,
`app/models/theme.rb`, and the `hugo` binary. Content blocks render through
`Blocks::Renderer::StaticSiteHtml`.

`.github/workflows/rspec.yml` still installs the `hugo` package — a leftover that can be dropped.

## Update (2026-10-06)

The decision stands: the CMS renders its static sites itself, with no external generator and one
fixed design. Since the port to Phoenix ([0007](0007-port-to-phoenix-and-sqlite.md)) the
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
