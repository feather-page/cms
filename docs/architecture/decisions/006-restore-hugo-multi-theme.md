# ADR-006: Restore Hugo with Multi-Theme Support

## Status
**Accepted**

## Date
2026-02-14

## Context

### Problem Statement
- ADR-005 removed Hugo in favor of Rails-native ERB rendering
- This eliminated multi-theme support (only one fixed design)
- Users need the ability to choose between different site designs
- Hugo's theme ecosystem provides proven, production-ready designs

### Requirements
- Restore multi-theme support for static sites
- Keep all features added since Hugo removal (projects, book blocks, Unsplash images)
- Support preview of themed sites
- Maintain testability with standard RSpec patterns

---

## Decision

**Hugo has been restored as the static site generator with multi-theme support.**

The CMS uses Hugo to build static sites. Each site can select from available themes. Themes are stored in `vendor/themes/` and referenced by the `Theme` model.

### Rationale
- **Multi-theme support**: Users can choose from different designs
- **Hugo ecosystem**: Access to proven theme architectures
- **Professional output**: Hugo produces optimized static HTML/CSS
- **Feature parity**: All new features (projects, book blocks, Unsplash) are supported in Hugo themes

---

## Implementation

### How It Works

**Deployment (Static Export):**
```
Deploy triggered → Hugo::BuildJob → write content files → hugo binary → static output → rclone sync
```

**Preview:**
```
Build preview triggered → Hugo::BuildJob (internal target) → static files → PreviewsController serves files
```

### Components

| Component | Purpose |
|-----------|---------|
| `Theme` model | Theme selection (name, hugo_theme identifier) |
| `Hugo::BuildJob` | Orchestrates Hugo build pipeline |
| `Hugo::ConfigFile` | Generates Hugo config.json |
| `Hugo::PostFile` | Generates post content with front matter |
| `Hugo::PageFile` | Generates page content (supports books/projects page types) |
| `Hugo::ProjectFile` | Generates project content with front matter |
| `Hugo::ImageFile` / `ImageVariant` | Manages image files for Hugo static directory |
| `Blocks::Renderer::HugoHtml` | Renders content blocks to Hugo-compatible HTML |
| `vendor/themes/simple_emoji/` | Default theme with full feature support |

### New Features in Hugo Themes

These features were added after the original Hugo removal and are now supported:
- **Project portfolio**: Project list pages and detail pages
- **Book blocks**: Inline book references in blog post content
- **Improved books grid**: Cover images, ratings, review links in grid layout
- **Unsplash header images**: Header images with photographer attribution

---

## Consequences

### Positive
- Multi-theme support restored
- All post-removal features preserved
- Hugo binary already in Docker image
- Theme-accurate preview available

### Negative
- Preview requires a build step (not live)
- Hugo binary dependency
- Two template languages (Go templates for themes, ERB for admin)

---

## Supersedes

This ADR supersedes [ADR-005: Static Sites with ERB Templates](005-replace-hugo-with-rails-rendering.md), restoring Hugo as the primary static site generator while keeping the ERB-based code as a reference implementation.
