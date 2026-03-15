# Lists & Cards Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all table-based and card-based content listings in the CMS admin with modern list-rows, a visual bookshelf, and updated empty states.

**Architecture:** New ViewComponent classes replace existing ERB partials and TableComponent usage. Each component gets an RSpec test and a Lookbook preview with sidecar CSS. Uses the existing design token system, Lucide IconComponent, ButtonComponent, and BadgeComponent.

**Tech Stack:** Rails 8.1, ViewComponent (with sidecar CSS), RSpec, FactoryBot, Lookbook (already installed), Stimulus, Turbo

**Spec:** `docs/superpowers/specs/2026-03-15-lists-and-cards-redesign.md`

**Already in place (from frontend-redesign merge):**
- Lookbook installed and mounted at `/lookbook`
- Design tokens in `base/_tokens.scss` (CSS custom properties)
- Sidecar CSS pattern (`.css` files next to components, imported via `components.css`)
- Core components: ButtonComponent, BadgeComponent, AlertComponent, CardComponent, TableComponent, PageHeaderComponent, PageLayoutComponent, ModalComponent, EmptyStateComponent, IconComponent (Lucide)
- Previews in `test/components/previews/`
- Views partially migrated (use PageHeaderComponent, EmptyStateComponent, but still use old partials/tables for content)

---

## Chunk 1: EmptyStateComponent Update + PostListItemComponent

### Task 1: Update EmptyStateComponent to support emoji mode

The existing EmptyStateComponent uses `icon` + `message`. Our design adds an optional `emoji` mode (large emoji instead of icon) and a `subtitle` field.

**Files:**
- Modify: `app/components/empty_state_component.rb`
- Modify: `app/components/empty_state_component.html.erb`
- Modify: `app/components/empty_state_component.css`
- Modify: `spec/components/empty_state_component_spec.rb` (create if missing)
- Modify: `test/components/previews/empty_state_component_preview.rb`

- [ ] **Step 1: Write tests for new emoji mode**

Create/update `spec/components/empty_state_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmptyStateComponent, type: :component do
  it "renders with icon (existing behavior)" do
    render_inline(described_class.new(icon: "file", message: "No items"))
    expect(page).to have_text("No items")
  end

  it "renders with emoji instead of icon" do
    render_inline(described_class.new(emoji: "✏️", message: "Noch keine Blogposts"))
    expect(page).to have_text("✏️")
    expect(page).to have_text("Noch keine Blogposts")
  end

  it "renders subtitle when provided" do
    render_inline(described_class.new(
      emoji: "📚",
      message: "Dein Buecherregal ist leer",
      subtitle: "Fuege dein erstes Buch hinzu.",
      action_label: "Neues Buch",
      action_href: "/books/new"
    ))
    expect(page).to have_text("Fuege dein erstes Buch hinzu.")
  end

  it "renders action button" do
    render_inline(described_class.new(icon: "file", message: "Empty", action_label: "Create", action_href: "/new"))
    expect(page).to have_link("Create")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/components/empty_state_component_spec.rb`
Expected: emoji-related tests FAIL

- [ ] **Step 3: Update component class**

Update `app/components/empty_state_component.rb`:

```ruby
# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  def initialize(icon: nil, emoji: nil, message:, subtitle: nil, action_label: nil, action_href: nil)
    @icon = icon
    @emoji = emoji
    @message = message
    @subtitle = subtitle
    @action_label = action_label
    @action_href = action_href
  end

  def render_action?
    @action_label.present? && @action_href.present?
  end

  def emoji_mode?
    @emoji.present?
  end
end
```

- [ ] **Step 4: Update template**

Update `app/components/empty_state_component.html.erb`:

```erb
<div class="empty-state">
  <% if emoji_mode? %>
    <div class="empty-state__emoji"><%= @emoji %></div>
  <% else %>
    <div class="empty-state__icon"><%= helpers.icon(@icon, size: 48) %></div>
  <% end %>
  <p class="empty-state__message"><%= @message %></p>
  <% if @subtitle %>
    <p class="empty-state__subtitle"><%= @subtitle %></p>
  <% end %>
  <% if render_action? %>
    <%= render ButtonComponent.new(label: @action_label, href: @action_href, variant: :primary, size: :sm) %>
  <% end %>
</div>
```

- [ ] **Step 5: Add emoji styles to CSS**

Add to `app/components/empty_state_component.css`:

```css
.empty-state__emoji {
  font-size: 48px;
  margin-bottom: var(--space-3);
}

.empty-state__subtitle {
  color: var(--color-text-tertiary);
  font-family: var(--font-sans);
  font-size: var(--text-sm);
  margin: 0 0 var(--space-4);
}
```

- [ ] **Step 6: Run tests**

Run: `bundle exec rspec spec/components/empty_state_component_spec.rb`
Expected: All PASS

- [ ] **Step 7: Add emoji variants to Lookbook preview**

Update `test/components/previews/empty_state_component_preview.rb` — add methods for each emoji variant (posts ✏️, books 📚, pages 📄, projects 🏗️, invitations ✉️) alongside existing icon-based previews.

- [ ] **Step 8: Commit**

```bash
git add app/components/empty_state_component* spec/components/empty_state_component_spec.rb test/components/previews/empty_state_component_preview.rb
git commit -m "Extend EmptyStateComponent with emoji mode and subtitle"
```

---

### Task 2: Create PostListItemComponent

Replaces `app/views/posts/_post.erb` (card-based layout with Edit/Delete buttons) with a compact list-row.

**Files:**
- Create: `app/components/post_list_item_component.rb`
- Create: `app/components/post_list_item_component.html.erb`
- Create: `app/components/post_list_item_component.css`
- Create: `spec/components/post_list_item_component_spec.rb`
- Create: `test/components/previews/post_list_item_component_preview.rb`
- Modify: `app/views/posts/index.erb`

- [ ] **Step 1: Write tests**

Create `spec/components/post_list_item_component_spec.rb` — test titled post (renders title, emoji, edit link), short post (renders content excerpt), draft badge, published badge, tags.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/components/post_list_item_component_spec.rb`

- [ ] **Step 3: Write component class**

`app/components/post_list_item_component.rb` — handles titled vs short posts, icon content (emoji/thumbnail/fallback icon), status badge, formatted date, edit path. Short posts truncate content to ~120 chars.

- [ ] **Step 4: Write template**

`app/components/post_list_item_component.html.erb` — link_to wrapping the entire row (navigates to edit). Structure: `.list-row` container with `.list-row__icon` (48x48), `.list-row__content` (title + meta), `.list-row__tags` (tag pills). No inline Edit/Delete buttons — clicking the row opens edit.

- [ ] **Step 5: Write sidecar CSS**

`app/components/post_list_item_component.css` — `.list-row` base styles (flex, padding, border-bottom, hover background, gap). This is a shared base class also used by DeploymentTargetRow, SiteUserRow, ProjectListItem later. Icon container 48x48 with border-radius. Title ellipsis. Meta line with date + badge. Tag pills.

- [ ] **Step 6: Add to components.css**

Add import line to `app/assets/stylesheets/components.css`:
```css
@import url("post_list_item_component.css");
```

- [ ] **Step 7: Run tests**

Run: `bundle exec rspec spec/components/post_list_item_component_spec.rb`
Expected: All PASS

- [ ] **Step 8: Create Lookbook preview**

`test/components/previews/post_list_item_component_preview.rb` — variants: with_title_and_emoji, short_post, draft, with_tags. Use `FactoryBot.build_stubbed` for posts.

- [ ] **Step 9: Integrate into posts index**

Update `app/views/posts/index.erb`: inside the existing `turbo_frame_tag(:posts)`, replace `render @posts` with iteration over `@posts` rendering `PostListItemComponent`. Keep the existing EmptyStateComponent fallback (update to use emoji mode: `emoji: "✏️"`). Keep pagination.

- [ ] **Step 10: Commit**

```bash
git commit -m "Replace post cards with PostListItemComponent list-rows"
```

---

## Chunk 2: BookshelfComponent + BookCoverComponent

### Task 3: Create BookCoverComponent

Individual book cover tile for the bookshelf.

**Files:**
- Create: `app/components/book_cover_component.rb`
- Create: `app/components/book_cover_component.html.erb`
- Create: `app/components/book_cover_component.css`
- Create: `spec/components/book_cover_component_spec.rb`
- Create: `test/components/previews/book_cover_component_preview.rb`

- [ ] **Step 1: Write tests**

Test: renders title + author, renders star rating for finished books with rating, renders emoji fallback when no cover image, does not render rating for want-to-read books.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Write component**

Class: `cover_image?` checks `@book.cover_image&.file&.attached?` (NOT `images` — Book has `has_one :cover_image`). `show_rating?` checks finished + rating present. `star_rating` renders ★/☆. `edit_path` uses `helpers.edit_book_path(@book)`.

Template: link_to wrapping cover. `.book-cover__image` (72x104px) with either the image or emoji fallback. Title (truncated 30), author (truncated 25), optional rating.

CSS: 72px wide, cover image 72x104 with border-radius 3px and box-shadow. Hover scale(1.05). Rating in amber color.

- [ ] **Step 4: Add to components.css, run tests**

- [ ] **Step 5: Create Lookbook preview** — finished_with_rating, want_to_read, currently_reading, no_rating variants.

- [ ] **Step 6: Commit**

```bash
git commit -m "Add BookCoverComponent with tests and Lookbook previews"
```

---

### Task 4: Create BookshelfComponent and integrate

Replaces the table+tabs in `app/views/books/index.erb` with a visual bookshelf grouped by status and year.

**Files:**
- Create: `app/components/bookshelf_component.rb`
- Create: `app/components/bookshelf_component.html.erb`
- Create: `app/components/bookshelf_component.css`
- Create: `spec/components/bookshelf_component_spec.rb`
- Create: `test/components/previews/bookshelf_component_preview.rb`
- Create: `app/javascript/controllers/toggle_controller.js` (if not already existing)
- Modify: `app/controllers/books_controller.rb` (remove status tab filtering)
- Modify: `app/views/books/index.erb`

- [ ] **Step 1: Write tests**

Test: groups books into "Currently Reading" section, groups "Want to Read", groups finished books by year (2026 and 2025 as separate sections), shows empty state when no books.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Write component**

Class: `currently_reading` scope (reading status, ordered by created_at desc), `want_to_read` scope, `finished_by_year` (group by read_at year, sort years descending). `average_rating(books)` for year stats.

Template: Three persistent sections (no tabs). Currently Reading + Want to Read always visible. Finished books as year sections with `data-controller="toggle"` for collapse/expand. Current year open by default, older years collapsed. Each section renders BookCoverComponent per book.

CSS: Section headers with status dots (amber for reading, gray for want). Grid with flex-wrap gap 16px. Year headers with chevron, bold title, right-aligned stats. Collapsible content.

- [ ] **Step 4: Create toggle Stimulus controller** (if not existing)

Simple controller: `static targets = ["content", "icon"]`, `static values = { open: Boolean }`. Toggle shows/hides content, rotates chevron.

- [ ] **Step 5: Modify BooksController**

The current controller filters by `reading_status` param (for tab switching). Change `index` action to load ALL books: `@books = policy_scope(Book)` without status filtering. The BookshelfComponent handles grouping internally.

- [ ] **Step 6: Update books/index.erb**

Replace the nav-tabs and TableComponent with: `render BookshelfComponent.new(books: @books, site: current_site)`. Keep PageHeaderComponent and "New Book" button.

- [ ] **Step 7: Add to components.css, run tests**

- [ ] **Step 8: Create Lookbook preview** — with_books (using real DB data or factory-created), empty state.

- [ ] **Step 9: Commit**

```bash
git commit -m "Replace books table with visual BookshelfComponent"
```

---

## Chunk 3: Pages/Navigation, DeploymentTargets, Users, Projects

### Task 5: Redesign Pages index with NavigationItemRowComponent + PageRowComponent

Replaces the two-table layout (NavigationComponent table + `_pages.erb` table) with card-rows.

**Files:**
- Create: `app/components/navigation_item_row_component.rb`
- Create: `app/components/navigation_item_row_component.html.erb`
- Create: `app/components/navigation_item_row_component.css`
- Create: `app/components/page_row_component.rb`
- Create: `app/components/page_row_component.html.erb`
- Create: `spec/components/navigation_item_row_component_spec.rb`
- Create: `spec/components/page_row_component_spec.rb`
- Create: `test/components/previews/navigation_item_row_component_preview.rb`
- Create: `test/components/previews/page_row_component_preview.rb`
- Modify: `app/components/navigation_component.html.erb` (use NavigationItemRowComponent)
- Modify: `app/views/pages/index.erb`
- Modify: `app/views/pages/_pages.erb`

- [ ] **Step 1: Write tests for NavigationItemRowComponent**

Test: renders title + slug from page, renders up/down arrows, disables up when first, disables down when last, renders edit link, renders remove button (X).

- [ ] **Step 2: Write tests for PageRowComponent**

Test: renders title + slug, renders "+ add to nav" button, renders edit link, renders delete button with turbo confirm.

- [ ] **Step 3: Implement both components**

NavigationItemRowComponent: card-style (border, border-radius 8px). Drag handle (⠿) + icon (32x32, page emoji) + title/slug + action buttons (↑↓ | ✎ ✕). All buttons 28x28. Separator between reorder and edit groups. Uses existing turbo-frame and PATCH/DELETE routes.

PageRowComponent: same card-style. Icon + title/slug + page-type badge + buttons (＋ | ✎ 🗑). Plus button POSTs to `navigation_items_path`. Uses existing turbo patterns.

Shared CSS: `.card-row` styles in a shared sidecar (or in navigation_item_row_component.css since page_row reuses same classes).

- [ ] **Step 4: Update NavigationComponent template**

Replace table rows with `NavigationItemRowComponent` rendering. Keep the `turbo-frame` ID on the container. Pass `first?`/`last?` based on position.

- [ ] **Step 5: Update pages index + _pages partial**

Replace `_pages.erb` table with iteration rendering `PageRowComponent`. Add EmptyStateComponent (emoji mode) for empty pages.

- [ ] **Step 6: Lookbook previews for both components**

- [ ] **Step 7: Run tests, commit**

```bash
git commit -m "Replace pages tables with card-row components"
```

---

### Task 6: Redesign DeploymentTargets with DeploymentTargetRowComponent

Replaces `app/views/deployment_targets/_deployment_target.erb` table row.

**Files:**
- Create: `app/components/deployment_target_row_component.rb`
- Create: `app/components/deployment_target_row_component.html.erb`
- Create: `app/components/deployment_target_row_component.css`
- Create: `spec/components/deployment_target_row_component_spec.rb`
- Create: `test/components/previews/deployment_target_row_component_preview.rb`
- Modify: `app/views/deployment_targets/index.erb`

- [ ] **Step 1: Write tests** — renders hostname, type label, Deploy as primary button, Preview as secondary. Icon color by type.

- [ ] **Step 2: Implement component** — `.list-row` based. Globe icon (40x40, green/amber by type). Hostname bold + type muted below. Deploy button primary, Preview secondary.

- [ ] **Step 3: Update index** — replace TableComponent with component iteration. Keep EmptyStateComponent.

- [ ] **Step 4: Lookbook preview** — production, staging variants.

- [ ] **Step 5: Run tests, commit**

```bash
git commit -m "Replace deployment targets table with list-row component"
```

---

### Task 7: Redesign Users with SiteUserRowComponent

Replaces `app/views/site_users/_site_user.erb` table row.

**Files:**
- Create: `app/components/site_user_row_component.rb`
- Create: `app/components/site_user_row_component.html.erb`
- Create: `app/components/site_user_row_component.css`
- Create: `spec/components/site_user_row_component_spec.rb`
- Create: `test/components/previews/site_user_row_component_preview.rb`
- Modify: `app/views/site_users/index.erb`

- [ ] **Step 1: Write tests** — renders email, user icon. Does not show delete for self.

- [ ] **Step 2: Implement component** — `.list-row` based. User icon (40x40) + email bold. Delete button conditional.

- [ ] **Step 3: Update index** — replace both TableComponent usages with component iteration. Update EmptyStateComponent to emoji mode for invitations.

- [ ] **Step 4: Lookbook preview, run tests, commit**

```bash
git commit -m "Replace users table with list-row component"
```

---

### Task 8: Redesign Projects with ProjectListItemComponent

Replaces `app/views/projects/_project.erb`.

**Files:**
- Create: `app/components/project_list_item_component.rb`
- Create: `app/components/project_list_item_component.html.erb`
- Create: `app/components/project_list_item_component.css`
- Create: `spec/components/project_list_item_component_spec.rb`
- Create: `test/components/previews/project_list_item_component_preview.rb`
- Modify: `app/views/projects/index.erb`

- [ ] **Step 1: Write tests** — renders title, company, role, emoji icon, status badge.

- [ ] **Step 2: Implement component** — `.list-row` based. Emoji icon (48x48) + title bold + company/role meta + status badge (completed/ongoing/paused).

- [ ] **Step 3: Update index** — replace `render @projects` with component iteration. Update EmptyStateComponent to emoji mode.

- [ ] **Step 4: Lookbook preview, run tests, commit**

```bash
git commit -m "Replace projects listing with list-row component"
```

---

## Chunk 4: Cleanup

### Task 9: Remove old partials and clean up

- [ ] **Step 1: Remove old partials**

Delete files no longer used:
- `app/views/posts/_post.erb`
- `app/views/books/_book.erb`
- `app/views/pages/_page.erb`
- `app/views/pages/_pages.erb`
- `app/views/site_users/_site_user.erb`
- `app/views/deployment_targets/_deployment_target.erb`
- `app/views/projects/_project.erb`

Only delete after verifying each view works.

- [ ] **Step 2: Clean up unused CSS from application.scss**

Remove old `.post-card` styles and any other dead CSS that was only used by old partials.

- [ ] **Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 4: Verify Lookbook**

Visit `/lookbook` and confirm all new component previews render correctly.

- [ ] **Step 5: Manual smoke test**

Check each view in the browser: Posts, Books, Pages, Deployment Targets, Users, Projects. Verify empty states, interactions (add/remove from nav, book year toggle, post click-to-edit).

- [ ] **Step 6: Commit**

```bash
git commit -m "Remove old partials and unused CSS after lists-and-cards migration"
```
