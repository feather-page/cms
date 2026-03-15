# Spec 1: Lists & Cards Redesign

**Scope:** CMS admin interface only. The statically generated frontend (`app/components/static_site/`, public-facing pages) is not affected.

**Goal:** Replace all table-based and card-based content listings with modern, consistent UI patterns that are visually appealing, scannable, and responsive.

**Context:** This is part of a broader UX improvement effort (3 specs total). This spec covers how collections of content are displayed. Spec 2 will cover navigation & layout, Spec 3 will cover forms & details.

---

## 1. Posts: Compact List-Rows

**Replaces:** White card blocks with full excerpt, naked "Edit"/"Delete" text links.

**Current problems:**
- Cards lack visual hierarchy — no status, no tags visible, no hover affordance
- Short-posts (without title) look identical to titled posts
- "Edit" and "Delete" as adjacent text links are easy to misclick
- No cover image shown in listing

### Design

Each post is a horizontal row element. No table headers.

```
┌──────────────────────────────────────────────────────────┐
│ [48x48 icon] Title (bold)                    [tag] [tag] │
│              14. Feb 2026 · Draft                        │
└──────────────────────────────────────────────────────────┘
```

**Left (48x48, border-radius 8px):**
- Post with emoji: emoji on warm beige background
- Post with thumbnail image: the image, `object-fit: cover`
- Short-post (no title): chat-bubble icon on muted background

**Center:**
- **Titled posts:** Title in `font-weight: 600`, below: date + status badge + optional tag count
- **Short-posts:** Content text truncated to ~120 chars in normal weight (replaces title), using a dedicated truncation (not the existing `content_excerpt` which defaults to 300). Below: date + status badge.

**Right:**
- Tag pills: small rounded chips with beige background

**Interactions:**
- Hover: subtle background color shift, cursor pointer
- Click anywhere on row: navigate to edit view
- No inline Edit/Delete links in the listing — edit is the click target, delete is in the edit view

**Status badges:**
- Published: green background, dark green text
- Draft: amber/yellow background, dark text

### ViewComponent

Create `PostListItemComponent` (replaces the current `_post.erb` partial):
- Inputs: `post` (Post model instance)
- Renders a single row
- Component-specific styles in `application.scss`

The index view renders a simple list of these components. No table markup.

---

## 2. Books: Visual Bookshelf

**Replaces:** Table with status tabs ("Want to Read" / "Currently Reading" / "Finished Reading").

**Current problems:**
- Tabbed table feels wrong for a bookshelf — tabs hide content
- Table is visually sparse, tiny thumbnails
- No rating visible despite model having `rating` column
- Status tabs have no active state styling
- Date format inconsistent (US in form, EU in table)

### Design

Three persistent sections, no tabs:

```
📖 Currently Reading · 2
[cover] [cover]

📋 Want to Read · 5
[cover] [cover] [cover]

▼ 2026                           12 books · avg ★★★★☆
[cover] [cover] [cover] [cover] [cover] [cover]

▶ 2025                           47 books · avg ★★★★☆
▶ 2024                           52 books · avg ★★★☆☆
```

**Section: "Currently Reading"** (always visible, top)
- Status dot (amber) + label + count
- Cover grid: books displayed as cover images, flex-wrap

**Section: "Want to Read"** (always visible, below)
- Status dot (gray) + label + count
- Cover grid, same layout

**Section: Finished books, grouped by year** (below)
- Year as heading (bold, 18px) with chevron (▼ open / ▶ closed)
- Right-aligned: "N books · avg ★★★★☆"
- Current year open by default, older years collapsed
- Collapsing via Stimulus controller (simple toggle)

**Book covers (per book):**
- Size: 72x104px, border-radius 3px, box-shadow for depth
- Books with cover image: the image
- Books without cover: emoji on beige background (fallback)
- Below cover: title (12px, font-weight 500), author (10px, muted)
- Finished books: star rating below author (11px, amber color)

**Interactions:**
- Click on cover: navigate to edit view
- Hover on cover: slight scale transform (1.05) + shadow increase
- Year sections: click header to toggle open/closed

**Grouping logic:**
- "Currently Reading" and "Want to Read" use `reading_status` enum
- "Currently Reading" and "Want to Read" ordered by `created_at` descending (these books have no meaningful `read_at`)
- Finished books grouped by `read_at` year
- Within each year: ordered by `read_at` descending
- Grouping is done in the `BookshelfComponent` (not a model scope) — it receives the full book relation and partitions it

### ViewComponents

- `BookshelfComponent`: the full bookshelf view (replaces `books/index.erb` content)
  - Inputs: `books` (relation), `site` (for new-book path)
  - Handles grouping logic
- `BookCoverComponent`: a single book cover tile
  - Inputs: `book` (Book model instance)
  - Renders cover + title + author + optional rating
  - Component-specific styles in `application.scss`

---

## 3. Pages: Cards with Navigation Section

**Replaces:** Two separate tables ("Pages in Navigation" / "Other Pages").

**Current problems:**
- Two tables for what is conceptually one list is confusing
- Empty tables show no helpful message
- Table headers are unnecessary for this small amount of data
- No visual distinction between navigation and non-navigation pages

### Design

Single view with two sections, same card style throughout:

**Navigation section (top):**

```
≡ NAVIGATION

┌─────────────────────────────────────────────────────────┐
│ ⠿ [emoji] Ueber mich    /about      [↑][↓] | [✎][✕]  │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│ ⠿ [emoji] Kontakt        /contact    [↑][↓] | [✎][✕]  │
└─────────────────────────────────────────────────────────┘
```

Each navigation item is a card (border, border-radius 8px, white background):
- **Drag handle** (⠿ grip icon, `cursor: grab`) — leftmost
- **Icon** (32x32, page emoji or fallback icon)
- **Title** (bold) + slug below (muted)
- **Action buttons** (28x28 icon buttons):
  - Up arrow / Down arrow (reorder)
  - Separator (`|`, 1px border, 20px height)
  - Edit pencil (navigate to page edit)
  - X mark (remove from navigation, red-tinted border) — this removes the NavigationItem, not the Page

**Note:** All navigation items are backed by a Page (`belongs_to :page`, required). There are no external/custom URL navigation items in the current data model.

**Labeled divider:** "Weitere Seiten" (centered text on a horizontal rule)

**Other pages section (below):**

Same card style as above (border, border-radius 8px):
- **Icon** (32x32, page icon)
- **Title** (bold) + slug below (muted) + optional page-type badge
- **Action buttons:**
  - Plus icon (add to navigation, green-tinted border)
  - Separator
  - Edit pencil
  - Trash icon (delete page, red-tinted border, with confirmation)

**Interactions:**
- Drag & drop: optional progressive enhancement (Stimulus + Sortable.js or similar). Falls back to up/down arrows which always work.
- All mutations (add/remove/reorder) use existing Turbo/server-side approach — no client-side state needed.

### ViewComponents

- `NavigationItemRowComponent`: a single sortable navigation item card
  - Inputs: `item` (NavigationItem), `first?`, `last?` (to disable up/down)
- `PageRowComponent`: a single page card (non-navigation)
  - Inputs: `page` (Page), `site` (for paths)

---

## 4. Deployment Targets: List-Rows

**Replaces:** Simple URL + Type table.

**Current problems:**
- "Deploy" button has same visual weight as "Edit" and "Preview"
- Very sparse, feels like placeholder UI

### Design

```
┌──────────────────────────────────────────────────────────┐
│ [🌐] rocu.de                        [Deploy] [Preview]  │
│      Production                                          │
└──────────────────────────────────────────────────────────┘
```

- **Icon** (40x40): globe icon, green background for Production, amber for Staging
- **Hostname** (bold) + type below (muted)
- **Deploy button:** Primary style (terracotta fill, white text) — this is the main action
- **Preview button:** Secondary style (outline)
- No Edit button in the row — edit is accessible via clicking the row or a settings icon

### ViewComponent

- `DeploymentTargetRowComponent`
  - Inputs: `target` (DeploymentTarget), `site`

---

## 5. Users: List-Rows

**Replaces:** Single-column "EMAIL" table.

**Current problems:**
- Only shows email, no visual identity
- No visible actions
- Sparse, feels unfinished

### Design

Same row pattern. Simple — email is the main content:

- **Icon** (40x40): user silhouette icon on muted background
- **Email** (bold)
- **Actions:** Delete button (if current user is admin/owner, don't show for self)

**Pending Invitations section** (below, same pattern as Pages):
- Labeled divider: "Ausstehende Einladungen"
- Each invitation as a card: mail icon + email + status badge ("Pending") + Resend/Delete buttons
- "Invite another user" button at top of section

### ViewComponent

- `SiteUserRowComponent`
  - Inputs: `user` (User), `current_user`, `site`

---

## 6. Projects: List-Rows

**Replaces:** Current card-based project listing.

**Design:** Same list-row pattern as Posts. Each project as a row with icon, title, and metadata. Follows the same visual language — no dedicated design needed beyond the shared row pattern.

### ViewComponent

- `ProjectListItemComponent`
  - Inputs: `project` (Project)

---

## 7. Empty States

**Applies to:** All list views when no content exists.

### Design

Centered block, vertically padded (48px top/bottom):

```
        [large emoji, 48px]
     Noch keine Blogposts
  Schreibe deinen ersten Post
     und teile ihn mit der Welt.
        [Primary Button]
```

- **Emoji** (48px font-size): content-type specific
- **Headline** (15px, font-weight 500, primary text color)
- **Subtitle** (13px, muted text color) — optional, 1-2 sentences
- **CTA Button** (primary style, links to new/create)

**Per content type:**

| Type | Emoji | Headline | Subtitle | CTA |
|------|-------|----------|----------|-----|
| Posts | ✏️ | Noch keine Blogposts | Schreibe deinen ersten Post und teile ihn mit der Welt. | Neuer Post |
| Books | 📚 | Dein Buecherregal ist leer | Fuege dein erstes Buch hinzu. | Neues Buch |
| Pages | 📄 | Keine Seiten vorhanden | Erstelle Seiten wie Impressum, About oder Kontakt. | Neue Seite |
| Projects | 🏗️ | Keine Projekte | Zeige deine Arbeit und Projekte. | Neues Projekt |
| Users (invitations) | ✉️ | Keine ausstehenden Einladungen | Lade weitere Nutzer ein, um an deiner Seite mitzuarbeiten. | Nutzer einladen |

### ViewComponent

- `EmptyStateComponent`
  - Inputs: `emoji`, `headline`, `subtitle` (optional), `cta_text`, `cta_path`
  - Component-specific styles in `application.scss`
  - Reusable across all list views

---

## Technical Notes

### Component Architecture

All new components follow existing patterns:
- ViewComponent classes in `app/components/`
- Styling: add component-specific CSS to `application.scss` (the current pattern). Sidecar CSS files are a future goal but not yet configured in the asset pipeline.
- Rendered via `component()` helper or direct `render`
- Icons via existing `IconComponent` (Bootstrap Icons in current codebase; Lucide migration is a separate effort)

### What Gets Replaced

| Current | New |
|---------|-----|
| `app/views/posts/_post.erb` | `PostListItemComponent` |
| `app/views/books/index.erb` + `_book.erb` | `BookshelfComponent` + `BookCoverComponent` |
| `app/components/navigation_component.html.erb` | `NavigationItemRowComponent` |
| `app/views/pages/_page.erb` + `_pages.erb` | `PageRowComponent` |
| `app/views/deployment_targets/_deployment_targets.erb` | `DeploymentTargetRowComponent` |
| `app/views/site_users/_site_user.erb` | `SiteUserRowComponent` |
| `app/views/projects/_project.erb` | `ProjectListItemComponent` |
| (none) | `EmptyStateComponent` (new) |

### Existing Infrastructure Used

- **Turbo Frames:** Existing turbo-frame patterns for add/remove/reorder stay as-is
- **Stimulus:** New controllers only where needed (book year toggle, optional drag-and-drop)
- **NavigationItem ordering:** Uses `positioned on: :navigation` (already in model) for position management
- **Styling:** Use existing CSS custom properties from `application.scss`. New color values can be added as CSS variables where needed.

### Out of Scope

- Static site components (`app/components/static_site/`)
- Navigation active states (Spec 2)
- Form improvements, button styling (Spec 3)
- Book edit form fixes — cover loss on validation failure, missing fields (Spec 3)
- Mobile navigation layout (Spec 2)
- Dark mode
