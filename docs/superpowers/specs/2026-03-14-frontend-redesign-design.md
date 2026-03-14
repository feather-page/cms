# Frontend Redesign: Clean & Minimal with ViewComponents

## Summary

Redesign the CMS backend UI to be clean, minimal, functional, and friendly. Build a systematic ViewComponent foundation with Lookbook catalog, then migrate all views. Keep all existing features, fix usability issues and inconsistencies along the way.

**Not in scope:**
- Static site (public-facing generated website), including `static_site/` components (`BooksListComponent`, `ProjectsListComponent`, `ProjectCardComponent`)
- Dark Mode implementation (but token structure must support it)
- Tag autocomplete/chips UI (future project)

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Visual direction | Clean & Minimal (Linear/Vercel style) | Functional tool, not a showcase |
| Migration strategy | Component-First Foundation (bottom-up) | Build catalog first, then migrate views systematically |
| CSS framework | Bootstrap 5.3 (keep, simplify) | Already integrated, no build-step needed with Importmap |
| Component catalog | Lookbook | Rails-native standard for ViewComponent previews |
| Post title behavior | Keep as-is (auto-show at 300 chars) | Deliberate microblog design for short posts |
| Icons | Lucide (ISC license) | Clean 1px stroke, minimal aesthetic, "feather" origin |
| SCSS organization | Global tokens + component sidecar styles | Tokens/base global, component CSS colocated |
| Typography | System font stack | Lightweight, no extra requests |
| Dark Mode | Remove existing implementation, keep token structure ready | Existing `[data-bs-theme="dark"]` block removed during SCSS split. Semantic tokens enable later `[data-theme="dark"]` override as separate project |
| `component()` helper | Keep | Existing helper pattern (`component('form/text_field', ...)` and `icon(name)`) stays; new components use same pattern |

## Design Tokens

Semantic CSS Custom Properties on `:root`. Components reference only semantic tokens, never primitive values.

### Primitives (internal only)

```
Gray scale:    50 #fafafa → 900 #171717 (neutral, 10 steps)
Accent:        500 #c45d3e (terracotta), 600 #a84e34
Red:           500 #ef4444
Green:         500 #22c55e
```

### Semantic Tokens

```
Backgrounds:   --color-bg-primary (white)
               --color-bg-secondary (gray-50)
               --color-bg-tertiary (gray-100)
               --color-bg-accent (accent-500)
               --color-bg-danger (red-500)

Text:          --color-text-primary (gray-900)
               --color-text-secondary (gray-600, WCAG AA compliant)
               --color-text-tertiary (gray-400)
               --color-text-accent (accent-500)
               --color-text-on-accent (white)
               --color-text-danger (red-500)

Borders:       --color-border-primary (gray-200)
               --color-border-secondary (gray-100)
               --color-border-focus (accent-500)

Spacing:       4px base grid
               --space-1: 0.25rem  (4px)
               --space-2: 0.5rem   (8px)
               --space-3: 0.75rem  (12px)
               --space-4: 1rem     (16px)
               --space-6: 1.5rem   (24px)
               --space-8: 2rem     (32px)
               --space-12: 3rem    (48px)

Radii:         --radius-sm: 0.25rem (4px)
               --radius-md: 0.375rem (6px)
               --radius-lg: 0.5rem (8px)

Shadows:       --shadow-sm: 0 1px 2px rgba(0,0,0,0.05)
               --shadow-md: 0 2px 4px rgba(0,0,0,0.05)

Transitions:   --duration-fast: 100ms
               --duration-normal: 150ms

Typography:    --font-sans: system-ui, -apple-system, sans-serif
               --font-mono: ui-monospace, 'SF Mono', monospace
               --text-xs: 0.75rem
               --text-sm: 0.875rem
               --text-base: 1rem
               --text-lg: 1.125rem
               --text-xl: 1.25rem
```

### Token Migration Mapping

Old token (current `application.scss`) → New token:

```
--color-bg            → --color-bg-primary
--color-bg-elevated   → --color-bg-primary (dropped, no elevation distinction in minimal design)
--color-bg-muted      → --color-bg-secondary
--color-bg-subtle     → --color-bg-tertiary
--color-primary       → --color-bg-accent / --color-text-accent (split by usage)
--color-primary-dark  → (dropped, use accent-600 primitive only in hover states)
--color-accent        → --color-text-accent
--color-text          → --color-text-primary
--color-text-muted    → --color-text-secondary
--color-text-subtle   → --color-text-tertiary
--color-border        → --color-border-primary

Bootstrap overrides ($primary, $secondary, etc.) remain in _reset.scss
to keep Bootstrap components functional, mapped to semantic tokens.
```

## Components

### New Components

| Component | Purpose | Variants |
|---|---|---|
| `ButtonComponent` | All buttons and button-like links | `primary`, `secondary`, `danger`, `ghost` / sizes `sm`, `md` / optional icon |
| `BadgeComponent` | Status labels, tags, counts | `neutral`, `accent`, `success`, `danger` |
| `AlertComponent` | Flash messages, inline notices | `info`, `success`, `danger` / dismissible option |
| `EmptyStateComponent` | Empty lists and sections | Icon + message + optional CTA button |
| `CardComponent` | Container for list items | Consistent padding, border, optional hover state |
| `TableComponent` | Data tables with optional actions | Header row + body rows, responsive |
| `PageHeaderComponent` | Page title + action buttons | Title left, actions right, consistent spacing |
| `PageLayoutComponent` | Page structure wrapper | PageHeader + content area, uniform margins |
| `ModalComponent` | Dialogs | Wraps native `<dialog>`, consistent styling |

### Existing Components to Refactor

| Component | Changes |
|---|---|
| `IconComponent` | Switch from Bootstrap Icons webfont to Lucide SVG inline icons |
| `SiteNavigationComponent` | Apply new tokens, fix active state highlighting |
| `NavigationComponent` | Apply new tokens, simplify |
| `Form::BaseInputComponent` | Update to semantic tokens, sidecar styles |
| `Form::TextFieldComponent` | Inherit updated base, sidecar styles |
| `Form::SelectComponent` | Inherit updated base, sidecar styles |
| `Form::CheckboxComponent` | Inherit updated base, sidecar styles |
| `Form::DatetimeFieldComponent` | Inherit updated base, sidecar styles |
| `Form::DateFieldComponent` | Inherit updated base, sidecar styles |
| `Form::EmailFieldComponent` | Inherit updated base, sidecar styles |
| `Form::EditorComponent` | Update wrapper styling to match tokens |
| `Form::TitleAndSlugComponent` | Update to new tokens |
| `Form::HeaderImagePickerComponent` | Simplify button grouping (thumbnail vs cover confusion), update tokens |
| `Form::SocialMediaPickerComponent` | Update to new tokens |
| `Form::LanguageSelectComponent` | Update to new tokens |
| `SocialMediaLinksComponent` | Update to new tokens |

### Not Componentized (by design)

- **Layouts** — remain as ERB templates
- **EditorJS** — stays as Stimulus controller; CSS adjusted to fit token system via `_editor.scss`
- **Pagination** — stays as Pagy helper
- **Block renderers** — stay as-is (content rendering, not admin UI)
- **Static site components** — `static_site/` namespace is out of scope (serves public site, not admin)

## Sidecar CSS Configuration

ViewComponent sidecar `.css` files require explicit configuration with Propshaft. Add to Phase 1:

```ruby
# config/initializers/view_component.rb
Rails.application.config.view_component.generate.sidecar = false  # Keep flat structure
```

Propshaft automatically serves assets from `app/components/` if the path is added:

```ruby
# config/application.rb (or initializer)
config.assets.paths << Rails.root.join("app/components")
```

Verify sidecar CSS loads correctly in the browser before building components.

## Icon Migration

### Bootstrap Icons → Lucide Name Mapping

| Bootstrap Icons name | Lucide name |
|---|---|
| `pen` | `pencil` |
| `file-text` | `file-text` |
| `book` | `book` |
| `rocket` | `rocket` |
| `gear` | `settings` |
| `people-fill` | `users` |
| `box-seam-fill` | `package` |
| `caret-up-square` | `chevron-up` |
| `caret-down-square` | `chevron-down` |
| `house` | `home` |
| `eye` | `eye` |
| `trash` | `trash-2` |
| `pencil-square` | `pencil` |
| `plus-lg` | `plus` |
| `x-lg` | `x` |
| `globe` | `globe` |
| `link-45deg` | `link` |

### Removal of Bootstrap Icons dependency

In Phase 1 (step 4), when rebuilding `IconComponent`:
1. Audit all views and components for direct `bi-*` CSS class usage outside `IconComponent`/`icon()` helper
2. Migrate any direct usage to use the `icon()` helper
3. Remove `*= require bootstrap-icons` from `application.scss`
4. Remove `vendor/stylesheets/bootstrap-icons.css` and related font files
5. Add `lucide-static` (or inline SVG approach) to the project

## File Structure

```
app/
  assets/stylesheets/
    application.scss              # Import-only entry point
    base/
      _tokens.scss                # CSS Custom Properties
      _reset.scss                 # Minimal reset, Bootstrap overrides
      _typography.scss            # Global type rules
    vendor/
      _editor.scss                # EditorJS styling (adapted to tokens)
    utilities/
      _helpers.scss               # Few global utilities

  components/
    button_component.rb
    button_component.html.erb
    button_component.css           # Sidecar styles
    icon_component.rb
    icon_component.html.erb
    badge_component.rb
    badge_component.html.erb
    badge_component.css
    alert_component.rb
    alert_component.html.erb
    alert_component.css
    empty_state_component.rb
    empty_state_component.html.erb
    empty_state_component.css
    card_component.rb
    card_component.html.erb
    card_component.css
    table_component.rb
    table_component.html.erb
    table_component.css
    page_header_component.rb
    page_header_component.html.erb
    page_header_component.css
    page_layout_component.rb
    page_layout_component.html.erb
    page_layout_component.css
    modal_component.rb
    modal_component.html.erb
    modal_component.css
    site_navigation_component.rb      # Refactored
    site_navigation_component.html.erb
    site_navigation_component.css
    navigation_component.rb           # Refactored
    navigation_component.html.erb
    navigation_component.css
    social_media_links_component.rb   # Refactored
    social_media_links_component.html.erb
    social_media_links_component.css
    form/                              # Existing, refactored
      base_input_component.rb
      text_field_component.rb
      text_field_component.html.erb
      text_field_component.css
      select_component.rb
      select_component.html.erb
      select_component.css
      checkbox_component.rb
      checkbox_component.html.erb
      checkbox_component.css
      datetime_field_component.rb
      datetime_field_component.html.erb
      datetime_field_component.css
      date_field_component.rb
      date_field_component.html.erb
      date_field_component.css
      email_field_component.rb
      email_field_component.html.erb
      email_field_component.css
      editor_component.rb
      editor_component.html.erb
      editor_component.css
      title_and_slug_component.rb
      title_and_slug_component.html.erb
      title_and_slug_component.css
      header_image_picker_component.rb
      header_image_picker_component.html.erb
      header_image_picker_component.css
      social_media_picker_component.rb
      social_media_picker_component.html.erb
      social_media_picker_component.css
      language_select_component.rb
      language_select_component/
        codes.rb
        language_select_component.html.erb
      language_select_component.css
    blocks/                            # Unchanged
      renderer/
    static_site/                       # Unchanged (out of scope)
      books_list_component.rb
      projects_list_component.rb
      project_card_component.rb
```

## Known Issues to Fix During Migration

### Usability
- Sub-navigation has no active state indicator
- Empty states missing on Pages, Projects, Books tabs
- Image picker button row confusing ("Thumbnail Upload Cover Upload")
- Mobile: Books table overflows, sub-nav wraps into 3 rows
- Draft checkbox defaults to unchecked (posts publish immediately)

### Accessibility
- Icon-only buttons (Books edit/delete) missing aria-labels
- Text-subtle color fails WCAG AA contrast (fixed by token --color-text-secondary at gray-600)

### Bugs (fix when encountered)
- Post title link in `_post.erb` uses `turbo_frame_tag(post)` which generates a link to `site_post_path` (show route) but `PostsController` has no `show` action. Fix: change the link to point to `edit_site_post_path` instead, or remove the link wrapper.
- N+1 queries on Books in post list (add `includes(:book)`)

### Consistency
- Post form has no title field (by design for microblog), Page form does — keep as-is but ensure visual consistency
- Submit button label casing inconsistent ("Update Deployment target")
- Required field indicators (*) missing on some forms
- Mixed button styles in same table rows (Books: text link + outlined + icon-only)

## Migration Phases

### Phase 1 — Foundation
1. Add Lookbook gem, configure route
2. Configure ViewComponent sidecar CSS with Propshaft (initializer + asset path)
3. Create `_tokens.scss` with design tokens
4. Split `application.scss` into `base/`, `vendor/`, `utilities/`; remove existing dark mode CSS block (`[data-bs-theme="dark"]`); remove dark mode detection script from `application.erb`
5. Integrate Lucide icons: add dependency, create icon name mapping, rebuild `IconComponent`, audit and migrate direct `bi-*` usage, remove Bootstrap Icons dependency
6. Build new core components with Lookbook previews:
   Button, Badge, Alert, EmptyState, Card, Table, PageHeader, PageLayout, Modal

### Phase 2 — Form Components
7. Refactor existing form components to new tokens (including SocialMediaPicker, LanguageSelect)
8. Extract sidecar styles from monolithic SCSS
9. Add Lookbook previews for all form components

### Phase 3 — View Migration (one at a time)
10. Posts (list + forms) — largest view, sets the standard
11. Pages
12. Books
13. Projects
14. Sites (list + settings)
15. Users + Invitations
16. Deployment Targets
17. Login/Sessions

### Phase 4 — Cleanup
18. Navigation components: active state fix, mobile optimization
19. Remove unused old CSS
20. Reduce Bootstrap overrides to minimum
21. Final audit: verify no `bi-*` classes remain, no old token names in use

### Per-View Migration Checklist
- [ ] All existing features preserved
- [ ] Uses new components (no raw Bootstrap HTML)
- [ ] Empty states added where missing
- [ ] Accessibility fixes applied (aria-labels, contrast)
- [ ] Bugs fixed if encountered
- [ ] Turbo Stream templates checked alongside views
- [ ] Mobile tested at 375px width

## Design Principles

1. **Functional over fancy** — every element earns its place
2. **Friendly, not sterile** — terracotta accent adds warmth to the minimal base
3. **Lightweight** — no extra fonts, no build steps, minimal shadows and decoration
4. **Understandable** — clear labels, helpful empty states, consistent patterns
5. **Component = source of truth** — if it appears more than once, it's a component
6. **Dark-Mode-ready tokens** — semantic naming, no hardcoded colors in components
