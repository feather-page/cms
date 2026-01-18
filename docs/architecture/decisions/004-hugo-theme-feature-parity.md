# ADR-004: Hugo Theme Feature Parity

## Status
**Accepted**

## Date
2026-01-18

## Context

### Problem Statement
- Meerkat CMS supports multiple Hugo themes (ink, simple_emoji)
- New features like star ratings need to work across all themes
- Without a policy, themes can diverge and users get inconsistent experiences
- Maintenance burden increases when features work differently per theme

### Requirements
- All themes must support the same content features
- Visual styling can differ, but functionality must be consistent
- New features must be implemented in all themes before being considered complete

---

## Decision

**We will maintain feature parity across all Hugo themes.**

### Rationale
- Users should be able to switch themes without losing functionality
- Reduces confusion and support burden
- Ensures consistent content rendering regardless of theme choice
- Makes testing more straightforward

---

## Implementation Guidelines

### When Adding New Features

1. **Identify affected templates**: Determine which Hugo templates need updates (single.html, list.html, etc.)
2. **Update ALL themes**: Implement the feature in every theme before considering the work complete
3. **Use consistent front matter**: Use the same JSON keys in PostFile/PageFile for all themes
4. **Test each theme**: Verify the feature works correctly in all themes

### Current Themes

| Theme | Location |
|-------|----------|
| ink | `vendor/themes/ink/` |
| simple_emoji | `vendor/themes/simple_emoji/` |

### Feature Checklist Template

When adding a new Hugo-related feature, verify:

- [ ] Feature works in `ink` theme
- [ ] Feature works in `simple_emoji` theme
- [ ] Front matter is consistent across themes
- [ ] Styling is appropriate for each theme's design language

---

## Consequences

### Positive
- Consistent user experience across themes
- Easier theme switching for users
- Simplified testing (test once, works everywhere)
- Clear expectations for feature completeness

### Negative
- More work when adding new features (must update all themes)
- Some features may not fit every theme's design language
- Theme-specific optimizations may be limited

### Neutral
- Themes can still have unique visual styling
- Theme-specific partials are allowed for styling purposes

---

## Current Feature Support

| Feature | ink | simple_emoji | Front Matter Key |
|---------|-----|--------------|------------------|
| Title | Yes | Yes | `title` |
| Date | Yes | Yes | `date` |
| Emoji | Yes | Yes | `emoji` |
| Header Image | Yes | Yes | `header_image` |
| Star Rating | Yes | Yes | `rating` |
| Short Post | Yes | Yes | `short` |
| URL/Slug | Yes | Yes | `url` |

---

## References
- Hugo documentation: https://gohugo.io/templates/
- `app/utils/hugo/post_file.rb` - Front matter generation
- `app/utils/hugo/page_file.rb` - Page front matter generation
