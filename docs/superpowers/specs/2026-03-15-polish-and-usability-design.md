# UX Redesign Spec 2: Polish & Usability

Continuation of the UX redesign effort. Spec 1 (Lists & Cards) delivered component-based list views across all sections. This spec addresses navigation clarity, date consistency, book cover handling, and basic mobile responsiveness.

## Scope

Seven changes grouped into infrastructure, navigation, content fixes, and responsive layout.

### Out of Scope

- Active states in navigation (already working)
- Cancel button styling (already gray/ghost)
- Rating field (exists via Reviews)
- ISBN field (not needed)
- Post form field order (acceptable as-is)

---

## 1. Infrastructure: DateHelper

**File:** `app/helpers/date_helper.rb`

A helper module with two methods for consistent date formatting across the application:

```ruby
module DateHelper
  def format_date(date)
    date&.strftime("%d.%m.%Y")
  end

  def format_month_year(date)
    date&.strftime("%m.%Y")
  end

  def format_datetime(datetime)
    datetime&.strftime("%d.%m.%Y, %H:%M")
  end
end
```

- Uses German numeric format (`15.03.2026`) via direct `strftime`, independent of I18n locale
- `format_month_year` for contexts where day precision is not meaningful (e.g. project periods)
- Replaces all scattered `strftime` calls in components and models
- Easily convertible to `I18n.l()` when localization is introduced later
- No changes to `config/locales/en.yml` — keeps locale file language-neutral

**Affected call sites:**
- `PostListItemComponent` — currently `strftime("%-d. %b %Y")`
- `Project#display_period` — currently `strftime("%B %Y")`, update format string to `"%m.%Y"` (model method, no helper — see Section 4)

**Not affected:** `Form::DatetimeFieldComponent` uses `I18n.l(datetime, format: :html_datetime)` which outputs ISO format for HTML `<input type="datetime-local">` — this must stay as-is.

---

## 2. Navigation: "Settings" → "Site"

**File:** `app/components/site_navigation_component.html.erb`

Rename the "Settings" navigation label to "Site". The icon (`:gear`) stays unchanged. This accurately describes the destination (site edit form for title, domain, language, copyright).

**Note:** The template uses `t('site_navigation.settings')` (plural) but the locale key is `site_navigation.setting` (singular) — a pre-existing mismatch. Fix both: update the YAML value to "Site" and align the template's `t()` call to use the correct key.

---

## 3. Breadcrumbs in Edit/New Views

**New component:** `app/components/breadcrumb_component.rb` + `.html.erb` + `.css`

A ViewComponent that renders a breadcrumb trail below the page header in edit and new views.

**Interface:**
```ruby
BreadcrumbComponent.new(items: [
  ["Blogposts", site_posts_path(current_site)],
  ["Edit Post"]
])
```

- Accepts an array of `[label, path]` pairs
- Last item is the current page (rendered as text, not a link)
- Items separated by `›`
- Styled with small text, `color-text-secondary`, positioned directly below `PageHeaderComponent`

**Breadcrumb mapping:**

| View | Breadcrumb |
|------|-----------|
| Posts new | Blogposts › New Post |
| Posts edit | Blogposts › Edit Post |
| Pages new | Pages › New Page |
| Pages edit | Pages › Edit Page |
| Books new | Books › New Book |
| Books edit | Books › Edit Book |
| Projects new | Projects › New Project |
| Projects edit | Projects › Edit Project |
| Site edit | Site (single item, no link) |
| Deployment Targets edit | Deployments › Edit Target |

No site name in breadcrumbs — already visible in the site navigation above.

**Implementation note:** `pages/edit.erb` uses `turbo_frame_tag(@page)` instead of `turbo_frame_tag(:content)` and does not render `PageHeaderComponent`. This view needs to be aligned with the other edit views before breadcrumbs can be added. No `deployment_targets/new.erb` exists — deployment targets are only edited, not created through a form.

---

## 4. Consistent Date Format

Replace all hardcoded `strftime` calls with `DateHelper` methods:

| Location | Before | After |
|----------|--------|-------|
| `PostListItemComponent` | `strftime("%-d. %b %Y")` | `format_date(post.publish_at)` |
| `Project#display_period` | `strftime("%B %Y")` | `strftime("%m.%Y")` (keep in model, not helper) |

Output format: `15.03.2026` for dates, `03.2026` for month-year periods.

**Note:** `Project#display_period` is a model method. Since `DateHelper` is a view helper and not available in models, keep the `strftime` call in the model but update the format string to `"%m.%Y"`. Update the project factory (`spec/factories/projects.rb`) and model specs (`spec/models/project_spec.rb`) which assert the old `"March 2019"` format.

---

## 5. Book Cover: Bug Fix + OpenLibrary Search in Edit Mode

### 5a. Bug Fix: Cover Lost on Validation Error

**Problem:** `cover_url` is a standalone parameter (not a database column on `Book`) used to trigger `RemoteImageCreator`. The hidden field in `_form.erb` (line 51) hardcodes its value to `nil` (`hidden_field_tag :cover_url, nil`), so it resets on re-render after a validation error.

**Fix:** In the controller's `create` and `update` actions, store the submitted `cover_url` in an instance variable (`@cover_url = params[:cover_url]`) so it survives re-renders. Update the hidden field in the form to use this value: `hidden_field_tag :cover_url, @cover_url`.

### 5b. OpenLibrary Search Available in Edit Mode

**Problem:** The OpenLibrary book search (which sets title, author, cover, ISBN) is only available when creating a new book.

**Change:** Make the search section visible in edit mode as well, so users can update a book's cover (and other metadata) by searching OpenLibrary again after initial creation. The search results overwrite the relevant fields, same as during creation.

**Files affected:**
- `app/views/books/_form.erb` — remove the new-record-only condition on the search section
- `app/controllers/books_controller.rb` — add `download_cover_if_present` call to the `update` action (currently only called in `create`)
- `app/javascript/controllers/book_search_controller.js` — verify it works without changes when form is in edit mode

---

## 6. read_at Default + Login Cleanup

### 6a. read_at Default

**File:** `app/models/book.rb`

Add a `before_validation` callback: when reading status changes to "finished" and `read_at` is nil, set `read_at` to `Date.today`. Follows the same pattern as `Post#set_publish_at`.

The existing validation (`validates :read_at, presence: true, if: :reading_status_finished?`) remains unchanged — `read_at` stays nil for non-finished books.

### 6b. Remove Login Cancel Button

**File:** `app/views/sessions/new.erb` (or equivalent login view)

Remove the Cancel button from the login form. There is no sensible destination for it.

---

## 7. Basic Mobile Responsive

Use Bootstrap's existing breakpoints (`576px` for sm, `768px` for md). No custom breakpoint tokens needed.

### Page Layout
- Reduce horizontal padding: `32px` → `24px` below `768px` → `16px` below `576px`

### Page Header
- Add `flex-wrap: wrap` below `576px` so title and action buttons stack vertically instead of colliding

### List Items (PostListItemComponent, PageRowComponent, ProjectListItemComponent, etc.)
- Below `576px`: hide action buttons, make the entire row a clickable link to the edit view
- On desktop: action buttons remain visible as before
- **Note:** `PostListItemComponent` already wraps content in a link. `PageRowComponent` uses a card-based structure with separate action buttons — the mobile approach may differ per component.

### Site Navigation
- No changes needed — horizontal scroll already works on mobile

---

## Testing

- RSpec unit test for `DateHelper` methods
- RSpec test for `BreadcrumbComponent` rendering
- Update existing component specs where date output format changes
- Model spec for `Book#read_at` default behavior
- Manual verification of book cover persistence through validation errors
- Manual verification of mobile layout at 576px and 768px breakpoints
