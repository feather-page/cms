# ADR-006: Restore Hugo Rendering

## Status
**Accepted**

## Date
2026-03-27

## Context

### Problem Statement
- ADR-005 replaced Hugo with Rails ERB templates for static site generation
- The ERB-based `StaticSite::ExportJob` and supporting renderers proved difficult to maintain as the site design evolved
- ERB templates required duplicating layout logic that Hugo handles natively (pagination, RSS, robots.txt, theming)
- Hugo's content model (Markdown + front matter) is a better fit for static site content than ERB templates rendering Rails models directly
- Preview via `PreviewsController` was implemented using complex routing concerns (`PreviewRouting`, `PreviewImageServing`) that had to replicate Hugo's URL scheme

### Requirements
- Maintain static site generation and deployment capability
- Support live preview without requiring a separate preview server
- Keep the Rails CMS as the source of truth for content
- Reduce template duplication between preview and production rendering

---

## Decision

**Hugo is restored as the static site generator. Rails writes Hugo content files; Hugo builds the final HTML.**

`Hugo::BuildJob` replaces `StaticSite::ExportJob`. The job writes Hugo-compatible content files (Markdown with front matter) to a source directory, runs the Hugo binary, then rclones the output to the deployment target. Preview uses the same job with a `preview: true` flag, writing to a separate output directory that `PreviewsController` serves directly.

### Rationale
- **Single rendering path**: Hugo renders both preview and production output, eliminating drift between the two
- **Hugo handles layout complexity**: Pagination, RSS, robots.txt, and theming are Hugo's native strengths
- **Simpler Rails code**: Rails only generates content files, not full HTML pages
- **Better testability of content**: Hugo content file generation (front matter, Markdown) is straightforward to test without a running server

---

## Implementation

### How It Works

**Preview:**
```
User requests preview → PreviewsController → Hugo::BuildJob (preview: true)
  → writes source files → runs hugo → serves output directory
```

**Deployment:**
```
Deploy triggered → DeploymentTarget#deploy → Hugo::BuildJob
  → writes source files → runs hugo → rclone sync to provider
```

### New Components

| Component | Purpose |
|-----------|---------|
| `app/jobs/hugo/build_job.rb` | Orchestrates Hugo build and rclone sync |
| `app/utils/hugo/*` | Content file writers (posts, pages, projects, RSS) |
| `app/components/blocks/renderer/hugo_html.rb` | Renders content blocks to Hugo-compatible HTML |
| `vendor/themes/simple_emoji/` | Hugo theme |
| `app/controllers/previews_controller.rb` | Serves Hugo-built preview output |

### Removed Components

| Component | Reason |
|-----------|--------|
| `app/jobs/static_site/export_job.rb` | Replaced by `Hugo::BuildJob` |
| `app/jobs/static_site/page_renderer.rb` | Replaced by Hugo templates |
| `app/jobs/static_site/rss_feed_renderer.rb` | Replaced by Hugo RSS template |
| `app/jobs/static_site/image_collector.rb` | Hugo::BuildJob handles image copying |
| `app/jobs/static_site/output_paths.rb` | Hugo determines output paths |
| `app/components/blocks/renderer/static_site_html.rb` | Replaced by `HugoHtml` renderer |
| `app/views/static_site/` | Replaced by Hugo theme templates |
| `app/views/layouts/static_site.html.erb` | Replaced by Hugo theme layout |
| `app/helpers/static_site_helper.rb` | URL helpers moved into Hugo content writers |
| `app/controllers/concerns/preview_routing.rb` | Preview now serves Hugo output directly |
| `app/controllers/concerns/preview_image_serving.rb` | Hugo output includes image files |
| `app/assets/stylesheets/static_site.css` | CSS lives in Hugo theme |

---

## Consequences

### Positive
- Single rendering path for preview and production
- Hugo handles pagination, RSS, sitemap natively
- Rails codebase is simpler (no HTML template duplication)
- Theme changes only require updating the Hugo theme

### Negative
- Hugo binary must be present in the deployment environment
- Build step required before preview is served (mitigated by `perform_now` in preview)
- Go template syntax required for theme development

### Neutral
- `Blocks::Renderer::HugoHtml` name is now accurate again (was kept from before ADR-005)
- Content block rendering pipeline unchanged

---

## Supersedes

This ADR supersedes [ADR-005: Static Sites with ERB Templates (Hugo Removal)](005-replace-hugo-with-rails-rendering.md).
