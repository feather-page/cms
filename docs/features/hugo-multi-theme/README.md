# Hugo Multi-Theme Support

## Overview

Sites can use different Hugo themes for their static output. Each theme provides its own layouts and styles while supporting all CMS features.

## Architecture

```
Site → Theme → Hugo Build → Static Files → Deploy
         ↓
  vendor/themes/{hugo_theme}/
```

## Available Themes

| Theme | Identifier | Description |
|-------|-----------|-------------|
| Simple Emoji | `simple_emoji` | Playful theme with emoji support, dark mode |

## Feature Support

All themes must support these features:
- Blog posts (with/without titles, short posts)
- Pages (default, books, projects page types)
- Projects (list and detail views)
- Book reviews (cover images, ratings, star display)
- Book blocks (inline book references in content)
- Unsplash header images with photographer attribution
- Social media links in footer
- Navigation menus
- RSS feeds
- Dark mode (via `prefers-color-scheme`)

## Theme Selection

Themes are selected in the site settings form. The selected theme determines:
- Which Hugo theme directory is used during build
- The visual design of the static site output

## Preview

Preview works by serving the Hugo build output via `PreviewsController`. The preview URL serves static files from `deployment_target.source_dir`.

## Adding New Themes

1. Create theme directory: `vendor/themes/{theme_name}/`
2. Add Hugo layouts in `layouts/_default/`
3. Add static assets in `static/`
4. Create `Theme` record in database
5. Ensure all required features are supported (see Feature Support above)
