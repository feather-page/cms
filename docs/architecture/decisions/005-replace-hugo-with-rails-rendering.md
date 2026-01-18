# ADR-005: Static Sites with ERB Templates (Hugo Removal)

## Status
**Accepted**

## Date
2026-01-18

## Context

### Problem Statement
- The CMS used Hugo as an external static site generator
- This created two separate "worlds": Go templates (Hugo) and ERB (Rails)
- The preview functionality required a Hugo build before viewing changes
- Hugo templates were difficult to test with RSpec
- Multiple themes (ink, simple_emoji) added maintenance overhead

### Requirements
- Maintain static site generation capability
- Improve developer experience with instant previews
- Simplify testing with standard Rails/RSpec patterns
- Reduce external dependencies

---

## Decision

**Static sites are now rendered directly with Rails ERB templates. Hugo has been removed.**

The CMS renders all pages (home, posts, pages) using standard Rails ERB templates. For deployment, `StaticSite::ExportJob` writes the rendered HTML to files. For preview, `PreviewsController` renders templates directly without any build step.

### Rationale
- **Unified stack**: All templates in ERB, one language to maintain
- **Instant preview**: Live rendering via `render()`, no build step needed
- **Better testability**: Standard ViewComponent and RSpec tests
- **Fewer dependencies**: No Hugo binary required
- **Simpler architecture**: One fixed design instead of multi-theme support

---

## Implementation

### How It Works

**Preview (Live):**
```
User edits content → PreviewsController → render(template, layout: 'static_site') → Browser
```

**Deployment (Static Export):**
```
Deploy triggered → StaticSite::ExportJob → render_to_string() → File.write() → rclone sync
```

### New Components

| Component | Purpose |
|-----------|---------|
| `app/views/layouts/static_site.html.erb` | Base layout with nav, footer, CSS |
| `app/views/static_site/home.html.erb` | Homepage with post list |
| `app/views/static_site/post.html.erb` | Single post with book card |
| `app/views/static_site/page.html.erb` | Static page |
| `app/helpers/static_site_helper.rb` | Shared helpers (stars, images, CSS) |
| `app/assets/stylesheets/static_site.css` | Inlined CSS (no external request) |
| `StaticSite::ExportJob` | Renders all pages to static files |
| `StaticSite::PrecompressJob` | Gzip/Brotli compression |
| `StaticSite::BooksListComponent` | Books grid ViewComponent |

### Removed Components

| Component | Reason |
|-----------|--------|
| `app/utils/hugo/*` | Replaced by ERB templates |
| `app/jobs/hugo/*` | Replaced by `StaticSite::ExportJob` |
| `vendor/themes/*` | Design now fixed in ERB |
| `app/models/theme.rb` | Multi-theme support removed |
| `hugo` binary | No longer needed |

---

## Consequences

### Positive
- Live preview without build step
- Single template language (ERB)
- Standard Rails testing patterns
- One fewer external dependency
- Simpler codebase

### Negative
- Lost multi-theme flexibility
- RSS feed and robots.txt now generated in Ruby

### Neutral
- Design is now fixed (simple_emoji style)
- Content block rendering still uses `Blocks::Renderer::HugoHtml` (historical name)

---

## Supersedes

This ADR supersedes [ADR-004: Hugo Theme Feature Parity](004-hugo-theme-feature-parity.md), which is no longer applicable since themes have been removed.
