# Static sites rendered with ERB

Status: accepted

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
