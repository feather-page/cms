# Replace Rails-Native Rendering with Hugo

## Problem

The current Rails-native static site rendering (ERB templates) has two issues:

1. **Performance**: Export is too slow and resource-intensive for large content sets — Rails renders each page individually, consuming CPU and memory.
2. **Ecosystem**: Every theme feature (syntax highlighting, responsive images, embed handling) must be hand-built in Ruby. Hugo's theme and plugin ecosystem provides this out of the box.

## Solution

Replace the ERB-based rendering pipeline with Hugo. The CMS becomes a headless editor that writes a complete Hugo source directory (content files, data files, config, images), then calls `hugo build` to generate the static site. The existing rclone deployment and deploy locking infrastructure remains unchanged.

## Architecture Overview

### Data Flow

```
CMS (Rails) ──writes──▸ Hugo Source Directory ──hugo build──▸ Static Output ──rclone──▸ Deployment Target
                │                                                    │
                │                                                    ▼
                ├── content/posts/*.html                      Preview Directory
                ├── content/pages/*.html                      (on-demand build)
                ├── content/projects/*.html
                ├── data/books.json
                ├── data/projects.json
                ├── data/site.json
                ├── static/images/{id}/*.webp
                ├── config.json
                └── themes/{theme}/ (symlink)
```

### Storage Structure

Keyed by deployment target ID (a site can have multiple targets: staging, production, backup):

```
storage/hugo/{deployment_target_id}/
  ├── source/              ← Hugo source directory (written by CMS)
  │   ├── config.json
  │   ├── content/
  │   │   ├── posts/
  │   │   ├── pages/
  │   │   └── projects/
  │   ├── data/
  │   │   ├── books.json
  │   │   ├── projects.json
  │   │   └── site.json
  │   ├── static/
  │   │   └── images/
  │   └── themes/ → symlink to vendor/themes/
  ├── preview/             ← Output from hugo build for preview
  └── deploy/              ← Output from hugo build for deployment
```

### Components

- **Hugo File Generators** (`app/utils/hugo/`) — Write content, config, data files to the source directory
- **HugoHtml Renderer** (`app/components/blocks/renderer/hugo_html/`) — Render blocks to HTML + shortcodes
- **Hugo::BuildJob** (`app/jobs/hugo/`) — Orchestrate: write files → `hugo build` → compress → deploy
- **Theme Model** (`app/models/theme.rb`) — DB table with theme name and Hugo theme identifier
- **Vendor Themes** (`vendor/themes/`) — Curated Hugo themes with shortcodes and partials

## Content Rendering Strategy

### Block Type → Hugo Output Mapping

| Block Type | Hugo Output | Rationale |
|-----------|-------------|-----------|
| paragraph | HTML | Simple inline content, no theme control needed |
| header | HTML (`<h2>`–`<h4>`) | Direct mapping, supports future ToC |
| quote | HTML (`<blockquote>` + `<cite>`) | Simple enough for raw HTML |
| list | HTML (`<ul>`/`<ol>`, nested) | Standard HTML |
| table | HTML (`<table>` with optional `<thead>`) | Standard HTML |
| code | Shortcode `{{</* highlight lang */>}}...{{</* /highlight */>}}` | Hugo Chroma syntax highlighting |
| image | Shortcode `{{</* image id="..." caption="..." */>}}` | Theme controls `<picture>`, variants, lazy loading |
| embed | Shortcode `{{</* youtube id */>}}`, `{{</* vimeo id */>}}`, or `{{</* embed url="..." */>}}` | Hugo built-in shortcodes + custom fallback |
| book | Shortcode `{{</* book id="..." */>}}` + data from `data/books.json` | Theme controls display, data centralized |

### Data Files

Books, projects, and site settings are exported as Hugo data files in `data/`. This allows themes to access structured data and render it with their own templates.

```json
// data/books.json
{
  "abc123": {
    "title": "The Pragmatic Programmer",
    "author": "David Thomas",
    "cover_url": "/images/books/abc123.webp",
    "emoji": "📖",
    "rating": 5
  }
}
```

```json
// data/projects.json
{
  "xyz789": {
    "title": "Feather-Page CMS",
    "status": "active",
    "period": "01.2024 – 03.2026",
    "short_description": "...",
    "links": { "github": "...", "live": "..." }
  }
}
```

```json
// data/site.json
{
  "title": "My Site",
  "description": "...",
  "social": { "github": "...", "mastodon": "..." }
}
```

### Frontmatter (Post Example)

```json
{
  "title": "My Blog Post",
  "date": "2026-03-15",
  "draft": false,
  "publishDate": "2026-03-15T10:00:00+01:00",
  "tags": ["ruby", "rails"],
  "summary": "First paragraph...",
  "header_image": "/images/abc123/desktop_x1.webp",
  "emoji": "✍️"
}
```

### Hugo Menus

Pages with navigation entries get `menu` in frontmatter. Weight is based on position in the CMS. This replaces the current `NavigationItem` model logic.

```json
{
  "title": "About Me",
  "menu": { "main": { "weight": 10 } }
}
```

### Hugo Config

```json
{
  "baseURL": "https://example.com/",
  "theme": "simple_emoji",
  "taxonomies": { "tag": "tags" },
  "related": {
    "threshold": 50,
    "includeNewer": true,
    "indices": [
      { "name": "tags", "weight": 100 },
      { "name": "date", "weight": 10 }
    ]
  },
  "outputs": {
    "home": ["HTML", "RSS"],
    "section": ["HTML", "RSS"]
  },
  "minify": true
}
```

## Hugo Features (Built-in, Zero Extra Work)

These features are provided by Hugo automatically with correct configuration:

- **Sitemap** (`sitemap.xml`) — currently missing from the ERB export
- **RSS Feeds** — per section (posts, projects), replaces the manual `RssFeedRenderer`
- **Open Graph / Twitter Cards** — via Hugo's embedded templates in theme `head` partial
- **Taxonomies** — automatic `/tags/` overview and `/tags/{tag}/` pages from post tags
- **Pagination** — built-in, replaces manual pagination in ExportJob
- **Draft/Scheduled Content** — `draft` and `publishDate` frontmatter fields
- **Content Summaries** — automatic (first 70 words) or via frontmatter `summary` field
- **Minification** — `hugo --minify` minifies HTML/CSS/JS output
- **Related Content** — built-in engine based on tag similarity, configured in `config.json`
- **Menus** — `site.Menus.main` in templates, populated from page frontmatter

## Build and Deploy Pipeline

### Hugo::BuildJob

Based on the current `StaticSite::ExportJob` architecture (parallel processing, deploy locking):

```
Hugo::BuildJob.perform(deployment_target)
  │
  ├── 1. Acquire deploy lock (existing optimistic locking)
  │
  ├── 2. Write Hugo source directory (parallelized)
  │   ├── Hugo::ConfigFile.write(site)
  │   ├── Hugo::PostFile.write(post)        ── parallel for all posts
  │   ├── Hugo::PageFile.write(page)        ── parallel for all pages
  │   ├── Hugo::ProjectFile.write(project)  ── parallel for all projects
  │   ├── Hugo::DataFile.write(:books)
  │   ├── Hugo::DataFile.write(:projects)
  │   ├── Hugo::DataFile.write(:site)
  │   ├── Hugo::ImageFile.write(image)      ── parallel for all variants
  │   └── Hugo::ThemeLinker.link(site)      ── symlink to vendor/themes/
  │
  ├── 3. Execute Hugo build
  │   └── hugo --source {source_path} --destination {output_path} --minify
  │
  ├── 4. Precompress (existing: gzip + brotli via PrecompressJob)
  │
  ├── 5. Rclone sync to deployment target
  │
  └── 6. Release deploy lock
```

### Error Handling

- **Hugo build fails**: Check exit code, log stderr, abort deploy, release lock
- **Timeout**: Hugo build gets a timeout (60s), abort on exceed
- **Missing images**: Warn but do not abort (Hugo still renders)

### Preview Flow

```
User clicks "Preview"
  │
  ├── Hugo::BuildJob.perform(preview: true)
  │   ├── Write source directory (same as above)
  │   └── hugo build --destination storage/hugo/{deployment_target_id}/preview/
  │   (no precompress, no rclone)
  │
  └── Rails serves preview directory
      └── GET /preview/sites/:id/*path → static file
```

## Theme System

### Theme Model

```ruby
# themes table
id:           uuid
name:         string     # Display name, e.g. "Simple Emoji"
hugo_theme:   string     # Hugo directory name, e.g. "simple_emoji"
created_at:   datetime
updated_at:   datetime
```

`Site` gets a `theme_id` foreign key reference.

### Theme Directory Structure

```
vendor/themes/
  └── simple_emoji/
      ├── layouts/
      │   ├── _default/
      │   │   ├── baseof.html
      │   │   ├── single.html
      │   │   ├── list.html
      │   │   └── home.html
      │   ├── posts/
      │   │   └── single.html
      │   ├── projects/
      │   │   └── single.html
      │   ├── partials/
      │   │   ├── image.html       ← base partial for responsive images
      │   │   ├── book.html        ← book display from data file
      │   │   ├── head.html        ← OG tags, Twitter Cards
      │   │   └── related.html     ← "Related Posts" section
      │   └── shortcodes/
      │       ├── image.html       ← {{</* image */>}} shortcode
      │       ├── book.html        ← {{</* book */>}} shortcode
      │       └── embed.html       ← {{</* embed */>}} fallback shortcode
      ├── static/
      │   ├── css/
      │   └── js/
      └── theme.toml
```

### Theme Requirements

Every curated theme must support:

- **Shortcodes**: `image`, `book`, `embed` (YouTube/Vimeo use Hugo built-ins)
- **Layouts**: home, single (post), single (project), list, page
- **Partials**: head (with OG/Twitter Cards), related content
- **Data access**: `site.Data.books`, `site.Data.projects`, `site.Data.site`
- **Taxonomies**: tag overview page, individual tag pages
- **Menus**: `site.Menus.main` for navigation
- **Pagination**: paginated list pages

### First Theme: `simple_emoji`

Based on the original Hugo `simple_emoji` theme (from git history before commit 1630147), extended with features added since then (visible in the current ERB templates). Serves as the reference implementation for additional themes.

## Cleanup (Final Step)

After Hugo integration is working and tested, remove the Rails-native rendering:

### Delete

- `app/jobs/static_site/` — entire directory
- `app/components/blocks/renderer/static_site_html/` — renderer + overrides
- `app/components/blocks/renderer/static_site_html.rb` — base class
- `app/views/static_site/` — all ERB templates
- `app/views/layouts/static_site.html.erb` — base layout
- `app/helpers/static_site_helper.rb`
- `app/controllers/concerns/preview_routing.rb`
- `app/controllers/concerns/preview_image_serving.rb`
- `app/assets/stylesheets/static_site.css`
- Associated specs

### Modify

- `PreviewsController` — rewrite to serve static files from Hugo preview directory
- `Editable` concern — remove `static_site_html` method
- Mark ADR-005 as superseded, write new ADR for Hugo return

### Keep (Reuse)

- `StaticSite::PrecompressJob` (reused by Hugo pipeline)
- `StaticSite::ParallelProcessor` (reused by Hugo pipeline)
- Rclone infrastructure (unchanged)
- Deploy locking on `DeploymentTarget` (unchanged)
- `Image::Variants` (unchanged)

## Dependencies

- Hugo binary must be installed on the server (already in Docker image)
- Hugo themes in `vendor/themes/` (new directory)

## Out of Scope

- Zip download of Hugo source directory (future feature)
- Theme preview images and metadata in DB
- Multilingual support
- Hugo image processing (CMS already generates variants)
- Table of contents
