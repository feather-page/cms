# UX Redesign Spec 2: Polish & Usability — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve CMS admin UX with navigation clarity, consistent date formatting, book cover fixes, breadcrumbs, and basic mobile responsiveness.

**Architecture:** Seven focused changes: a DateHelper for consistent formatting, a BreadcrumbComponent for edit/new views, navigation label fix, book cover persistence and OpenLibrary in edit mode, read_at default callback, login cleanup, and responsive CSS via Bootstrap breakpoints.

**Tech Stack:** Rails 8, ViewComponent, Stimulus, Bootstrap 5, RSpec

---

## Chunk 1: Infrastructure + Navigation + Dates

### Task 1: DateHelper

**Files:**
- Create: `app/helpers/date_helper.rb`
- Create: `spec/helpers/date_helper_spec.rb`

- [ ] **Step 1: Write the failing tests**

```ruby
# spec/helpers/date_helper_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe DateHelper, type: :helper do
  describe "#format_date" do
    it "formats a date as dd.mm.yyyy" do
      expect(helper.format_date(Date.new(2026, 3, 15))).to eq("15.03.2026")
    end

    it "returns nil for nil" do
      expect(helper.format_date(nil)).to be_nil
    end
  end

  describe "#format_month_year" do
    it "formats a date as mm.yyyy" do
      expect(helper.format_month_year(Date.new(2019, 3, 1))).to eq("03.2019")
    end

    it "returns nil for nil" do
      expect(helper.format_month_year(nil)).to be_nil
    end
  end

  describe "#format_datetime" do
    it "formats a datetime as dd.mm.yyyy, HH:MM" do
      expect(helper.format_datetime(Time.zone.local(2026, 3, 15, 14, 30))).to eq("15.03.2026, 14:30")
    end

    it "returns nil for nil" do
      expect(helper.format_datetime(nil)).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/helpers/date_helper_spec.rb`
Expected: FAIL — `NoMethodError: undefined method 'format_date'`

- [ ] **Step 3: Write the helper**

```ruby
# app/helpers/date_helper.rb
# frozen_string_literal: true

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

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/helpers/date_helper_spec.rb`
Expected: 6 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/helpers/date_helper.rb spec/helpers/date_helper_spec.rb
git commit -m "feat: add DateHelper for consistent date formatting"
```

---

### Task 2: Replace strftime in PostListItemComponent

**Files:**
- Modify: `app/components/post_list_item_component.rb:45-47`
- Modify: `spec/components/post_list_item_component_spec.rb:28`

- [ ] **Step 1: Update the spec to expect new format**

In `spec/components/post_list_item_component_spec.rb`, change line 28:

```ruby
# Before:
expect(page).to have_text("14. Feb 2026")
# After:
expect(page).to have_text("14.02.2026")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/components/post_list_item_component_spec.rb`
Expected: FAIL — expected "14.02.2026" but got "14. Feb 2026"

- [ ] **Step 3: Update the component**

In `app/components/post_list_item_component.rb`, replace lines 45-47:

```ruby
# Before:
def formatted_date
  @post.publish_at&.strftime("%-d. %b %Y")
end

# After:
def formatted_date
  helpers.format_date(@post.publish_at)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/components/post_list_item_component_spec.rb`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add app/components/post_list_item_component.rb spec/components/post_list_item_component_spec.rb
git commit -m "refactor: use DateHelper in PostListItemComponent"
```

---

### Task 3: Replace strftime in Project#display_period

**Files:**
- Modify: `app/models/project.rb:34-35`
- Modify: `spec/models/project_spec.rb:136-158`
- Modify: `spec/factories/projects.rb:5`

- [ ] **Step 1: Update specs to expect new format**

In `spec/models/project_spec.rb`, update the display_period tests:

```ruby
# Line 136 — when period is present, keep as-is (returns raw period field)
# No change needed for this test case

# Line 148 — with ended_at present:
expect(project.display_period).to eq("03.2019 - 08.2020")

# Line 158 — with ended_at nil (ongoing):
expect(project.display_period).to eq("03.2019 - ongoing")
```

In `spec/factories/projects.rb`, update line 5:

```ruby
# Before:
period { "#{Faker::Date.between(from: 5.years.ago, to: 2.years.ago).strftime('%B %Y')} - #{Faker::Date.between(from: 2.years.ago, to: Time.zone.today).strftime('%B %Y')}" }

# After:
period { "#{Faker::Date.between(from: 5.years.ago, to: 2.years.ago).strftime('%m.%Y')} - #{Faker::Date.between(from: 2.years.ago, to: Time.zone.today).strftime('%m.%Y')}" }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/project_spec.rb`
Expected: FAIL on display_period tests

- [ ] **Step 3: Update the model**

In `app/models/project.rb`, replace lines 34-35:

```ruby
# Before:
start_str = started_at.strftime("%B %Y")
end_str = ended_at&.strftime("%B %Y") || "ongoing"

# After:
start_str = started_at.strftime("%m.%Y")
end_str = ended_at&.strftime("%m.%Y") || "ongoing"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/project_spec.rb`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add app/models/project.rb spec/models/project_spec.rb spec/factories/projects.rb
git commit -m "refactor: use numeric date format in Project#display_period"
```

---

### Task 4: Navigation "Settings" → "Site"

**Files:**
- Modify: `config/locales/en.yml:160`
- Modify: `app/components/site_navigation_component.html.erb:22`

- [ ] **Step 1: Fix the locale key value**

In `config/locales/en.yml`, change line 160:

```yaml
# Before:
    setting: Settings
# After:
    setting: Site
```

- [ ] **Step 2: Fix the template to use the correct key**

In `app/components/site_navigation_component.html.erb`, change line 22:

```erb
<!-- Before: -->
<%= navigation_item(t('site_navigation.settings'), helpers.edit_site_path(current_site), icon: :gear) %>

<!-- After: -->
<%= navigation_item(t('site_navigation.setting'), helpers.edit_site_path(current_site), icon: :gear) %>
```

- [ ] **Step 3: Run existing navigation specs**

Run: `bundle exec rspec spec/components/site_navigation_component_spec.rb`
Expected: All pass (or no spec exists — verify manually)

- [ ] **Step 4: Commit**

```bash
git add config/locales/en.yml app/components/site_navigation_component.html.erb
git commit -m "fix: rename Settings to Site in navigation, fix i18n key"
```

---

### Task 5: Remove Login Cancel Button

**Files:**
- Modify: `app/views/sessions/new.erb:13-16`

- [ ] **Step 1: Remove the Cancel button**

In `app/views/sessions/new.erb`, replace lines 13-16:

```erb
<!-- Before: -->
      <div class="d-flex gap-2">
        <%= render ButtonComponent.new(label: "Continue", variant: :primary, type: "submit") %>
        <%= render ButtonComponent.new(label: "Cancel", variant: :ghost, href: root_path, "data-turbo-frame": "_top") %>
      </div>

<!-- After: -->
      <div class="d-flex gap-2">
        <%= render ButtonComponent.new(label: "Continue", variant: :primary, type: "submit") %>
      </div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/sessions/new.erb
git commit -m "fix: remove cancel button from login page"
```

---

## Chunk 2: Book Model + Cover Fixes

### Task 6: Book read_at Default

**Files:**
- Modify: `app/models/book.rb`
- Create or modify: `spec/models/book_spec.rb`

- [ ] **Step 1: Write the failing tests and update existing spec**

Add to `spec/models/book_spec.rb`:

```ruby
describe "#set_read_at_default" do
  let(:site) { create(:site) }

  it "sets read_at to today when status changes to finished and read_at is nil" do
    book = build(:book, site: site, reading_status: :finished, read_at: nil)
    book.valid?
    expect(book.read_at).to eq(Date.today)
  end

  it "does not overwrite existing read_at when status changes to finished" do
    book = build(:book, site: site, reading_status: :finished, read_at: Date.new(2025, 1, 15))
    book.valid?
    expect(book.read_at).to eq(Date.new(2025, 1, 15))
  end

  it "does not set read_at for non-finished status" do
    book = build(:book, site: site, reading_status: :reading, read_at: nil)
    book.valid?
    expect(book.read_at).to be_nil
  end
end
```

Also update the existing "requires read_at" test (around line 27-30) — with the new callback, a finished book with `read_at: nil` will auto-fill `read_at` before validation, so the test needs to change:

```ruby
# Before (line 27-30):
it "requires read_at" do
  book = build(:book, reading_status: :finished, read_at: nil)
  expect(book).not_to be_valid
  expect(book.errors[:read_at]).to be_present
end

# After — test that callback auto-fills read_at:
it "auto-fills read_at when finished and read_at is nil" do
  book = build(:book, reading_status: :finished, read_at: nil)
  expect(book).to be_valid
  expect(book.read_at).to eq(Date.today)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/book_spec.rb`
Expected: FAIL — the new `#set_read_at_default` tests fail, and the updated existing test fails (callback not yet added)

- [ ] **Step 3: Add the callback**

In `app/models/book.rb`, add after line 11 (after the enum):

```ruby
before_validation :set_read_at_default

# ... (existing validations) ...

private

def set_read_at_default
  self.read_at ||= Date.today if reading_status_finished?
end
```

Full file should look like:

```ruby
class Book < ApplicationRecord
  belongs_to :site
  belongs_to :post, optional: true, dependent: :destroy
  has_one :cover_image,
          -> { where(imageable_type: "Book") },
          class_name: "Image",
          foreign_key: "imageable_id",
          dependent: :destroy,
          inverse_of: false

  enum :reading_status, { want_to_read: 0, reading: 1, finished: 2 }, prefix: true

  before_validation :set_read_at_default

  validates :title, presence: true
  validates :author, presence: true
  validates :read_at, presence: true, if: :reading_status_finished?
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true

  def review?
    post.present?
  end

  def review_title_suggestion
    "Review: #{title}"
  end

  scope :ordered, -> { order(read_at: :desc) }
  scope :by_status, ->(status) { where(reading_status: status) }

  delegate :year, to: :read_at, allow_nil: true

  private

  def set_read_at_default
    self.read_at ||= Date.today if reading_status_finished?
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/book_spec.rb`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add app/models/book.rb spec/models/book_spec.rb
git commit -m "feat: default read_at to today when book status is finished"
```

---

### Task 7: Fix Book Cover Loss on Validation Error

**Files:**
- Modify: `app/controllers/books_controller.rb:16-23`
- Modify: `app/views/books/_form.erb:51`

- [ ] **Step 1: Store cover_url in controller for re-renders**

In `app/controllers/books_controller.rb`, update the `create` action (lines 16-23):

```ruby
# Before:
def create
  @book = current_site.books.new(book_params)

  return unless @book.save

  download_cover_if_present
  turbo_redirect_to(site_books_path(current_site), notice: t(".notice"))
end

# After:
def create
  @book = current_site.books.new(book_params)
  @cover_url = params[:cover_url]

  return unless @book.save

  download_cover_if_present
  turbo_redirect_to(site_books_path(current_site), notice: t(".notice"))
end
```

- [ ] **Step 2: Update the hidden field in the form**

In `app/views/books/_form.erb`, replace line 51:

```erb
<!-- Before: -->
<%= hidden_field_tag :cover_url, nil, data: { book_search_target: 'coverUrl' } %>

<!-- After: -->
<%= hidden_field_tag :cover_url, @cover_url, data: { book_search_target: 'coverUrl' } %>
```

- [ ] **Step 3: Verify manually**

1. Create a new book, search OpenLibrary, select a book with a cover
2. Clear the title field (to trigger validation error)
3. Submit — the form should re-render with the cover URL preserved in the hidden field and the cover preview still visible

- [ ] **Step 4: Commit**

```bash
git add app/controllers/books_controller.rb app/views/books/_form.erb
git commit -m "fix: preserve cover_url through form validation errors"
```

---

### Task 8: OpenLibrary Search in Edit Mode + download_cover_if_present in update

**Files:**
- Modify: `app/views/books/_form.erb:9,22`
- Modify: `app/controllers/books_controller.rb:25-29`

- [ ] **Step 1: Remove the new-record-only condition on search**

In `app/views/books/_form.erb`, remove the `unless book.persisted?` guard. Replace lines 9-22:

```erb
<!-- Before: -->
    <% unless book.persisted? %>
      <div class="mb-3">
        <%= label_tag :book_search, t('books.search_openlibrary'), class: 'form-label' %>
        <%= text_field_tag :book_search, nil,
            class: 'form-control',
            data: {
              book_search_target: 'query',
              action: 'input->book-search#search'
            },
            placeholder: t('books.search_placeholder'),
            autocomplete: 'off' %>
        <div data-book-search-target="results" class="list-group mt-1"></div>
      </div>
    <% end %>

<!-- After: -->
      <div class="mb-3">
        <%= label_tag :book_search, t('books.search_openlibrary'), class: 'form-label' %>
        <%= text_field_tag :book_search, nil,
            class: 'form-control',
            data: {
              book_search_target: 'query',
              action: 'input->book-search#search'
            },
            placeholder: t('books.search_placeholder'),
            autocomplete: 'off' %>
        <div data-book-search-target="results" class="list-group mt-1"></div>
      </div>
```

- [ ] **Step 2: Add download_cover_if_present to update action and store @cover_url**

In `app/controllers/books_controller.rb`, update the `update` action (lines 25-29):

```ruby
# Before:
def update
  return unless @book.update(book_params)

  turbo_redirect_to(site_books_path(current_site), notice: t(".notice"))
end

# After:
def update
  @cover_url = params[:cover_url]
  return unless @book.update(book_params)

  download_cover_if_present
  turbo_redirect_to(site_books_path(current_site), notice: t(".notice"))
end
```

- [ ] **Step 3: Verify manually**

1. Edit an existing book
2. Use OpenLibrary search to find a different book
3. Select it — cover preview should update
4. Save — new cover should be downloaded and attached

- [ ] **Step 4: Commit**

```bash
git add app/views/books/_form.erb app/controllers/books_controller.rb
git commit -m "feat: enable OpenLibrary search in book edit mode"
```

---

## Chunk 3: BreadcrumbComponent

### Task 9: Create BreadcrumbComponent

**Files:**
- Create: `app/components/breadcrumb_component.rb`
- Create: `app/components/breadcrumb_component.html.erb`
- Create: `app/components/breadcrumb_component.css`
- Create: `spec/components/breadcrumb_component_spec.rb`

- [ ] **Step 1: Write the failing tests**

```ruby
# spec/components/breadcrumb_component_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreadcrumbComponent, type: :component do
  it "renders breadcrumb items with links" do
    render_inline(described_class.new(items: [
      ["Blogposts", "/sites/1/posts"],
      ["Edit Post"]
    ]))

    expect(page).to have_link("Blogposts", href: "/sites/1/posts")
    expect(page).to have_text("Edit Post")
    expect(page).to have_css(".breadcrumb__separator", text: "›")
  end

  it "renders last item as text without link" do
    render_inline(described_class.new(items: [
      ["Blogposts", "/sites/1/posts"],
      ["Edit Post"]
    ]))

    expect(page).not_to have_link("Edit Post")
  end

  it "renders single item without separator" do
    render_inline(described_class.new(items: [["Site"]]))

    expect(page).to have_text("Site")
    expect(page).not_to have_css(".breadcrumb__separator")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/components/breadcrumb_component_spec.rb`
Expected: FAIL — `uninitialized constant BreadcrumbComponent`

- [ ] **Step 3: Create the component**

```ruby
# app/components/breadcrumb_component.rb
# frozen_string_literal: true

class BreadcrumbComponent < ViewComponent::Base
  def initialize(items:)
    @items = items
  end
end
```

```erb
<!-- app/components/breadcrumb_component.html.erb -->
<nav class="breadcrumb-nav" aria-label="Breadcrumb">
  <% @items.each_with_index do |(label, path), index| %>
    <% if index > 0 %>
      <span class="breadcrumb__separator" aria-hidden="true">›</span>
    <% end %>
    <% if path %>
      <%= link_to label, path, class: "breadcrumb__link", data: { turbo_frame: :content } %>
    <% else %>
      <span class="breadcrumb__current" aria-current="page"><%= label %></span>
    <% end %>
  <% end %>
</nav>
```

```css
/* app/components/breadcrumb_component.css */
.breadcrumb-nav {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-xs);
  color: var(--color-text-tertiary);
  margin-bottom: var(--space-4);
}

.breadcrumb__link {
  color: var(--color-text-secondary);
  text-decoration: none;
}

.breadcrumb__link:hover {
  color: var(--color-text-primary);
  text-decoration: underline;
}

.breadcrumb__separator {
  color: var(--color-text-tertiary);
}

.breadcrumb__current {
  color: var(--color-text-tertiary);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/components/breadcrumb_component_spec.rb`
Expected: 3 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/components/breadcrumb_component.rb app/components/breadcrumb_component.html.erb app/components/breadcrumb_component.css spec/components/breadcrumb_component_spec.rb
git commit -m "feat: add BreadcrumbComponent"
```

---

### Task 10: Add Breadcrumbs to Edit/New Views

**Files:**
- Modify: `app/views/posts/new.erb`
- Modify: `app/views/posts/edit.erb`
- Modify: `app/views/pages/new.erb`
- Modify: `app/views/pages/edit.erb`
- Modify: `app/views/books/new.erb`
- Modify: `app/views/books/edit.erb`
- Modify: `app/views/projects/new.erb`
- Modify: `app/views/projects/edit.erb`
- Modify: `app/views/deployment_targets/edit.erb`

- [ ] **Step 1: Fix pages/edit.erb to match the pattern**

`pages/edit.erb` currently uses `turbo_frame_tag(@page)` and doesn't render `PageHeaderComponent`. Align it with the other edit views:

```erb
<!-- app/views/pages/edit.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Pages", site_pages_path(current_site)], ["Edit Page"]]) %>
  <%= render PageHeaderComponent.new(title: "Edit Page") %>
  <%= render "form", page: @page %>
<% end %>
```

- [ ] **Step 2: Add breadcrumbs to all post views**

```erb
<!-- app/views/posts/new.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Blogposts", site_posts_path(current_site)], ["New Post"]]) %>
  <%= render PageHeaderComponent.new(title: "New Post") %>
  <%= render "form", post: @post %>
<% end %>
```

```erb
<!-- app/views/posts/edit.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Blogposts", site_posts_path(current_site)], ["Edit Post"]]) %>
  <%= render PageHeaderComponent.new(title: "Edit Post") %>
  <%= render "form", post: @post %>
<% end %>
```

- [ ] **Step 3: Add breadcrumbs to pages/new**

```erb
<!-- app/views/pages/new.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Pages", site_pages_path(current_site)], ["New Page"]]) %>
  <%= render PageHeaderComponent.new(title: "New Page") %>
  <%= render "form", page: @page %>
<% end %>
```

- [ ] **Step 4: Add breadcrumbs to book views**

```erb
<!-- app/views/books/new.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Books", site_books_path(current_site)], [t('books.new_book')]]) %>
  <%= render PageHeaderComponent.new(title: t('books.new_book')) %>
  <%= render "form", book: @book %>
<% end %>
```

```erb
<!-- app/views/books/edit.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Books", site_books_path(current_site)], [t('books.edit_book')]]) %>
  <%= render PageHeaderComponent.new(title: t('books.edit_book')) %>
  <%= render "form", book: @book %>
<% end %>
```

- [ ] **Step 5: Add breadcrumbs to project views**

```erb
<!-- app/views/projects/new.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Projects", site_projects_path(current_site)], ["New Project"]]) %>
  <%= render PageHeaderComponent.new(title: "New Project") %>
  <%= render "form", project: @project %>
<% end %>
```

```erb
<!-- app/views/projects/edit.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Projects", site_projects_path(current_site)], ["Edit Project"]]) %>
  <%= render PageHeaderComponent.new(title: "Edit Project") %>
  <%= render "form", project: @project %>
<% end %>
```

- [ ] **Step 6: Add breadcrumbs to deployment_targets/edit**

```erb
<!-- app/views/deployment_targets/edit.erb — replace entire file -->
<%= turbo_frame_tag(:content) do %>
  <%= render BreadcrumbComponent.new(items: [["Deployments", site_deployment_targets_path(current_site)], ["Edit Target"]]) %>
  <%= render PageHeaderComponent.new(title: "Edit Deployment Target") %>
  <%= render "form", deployment_target: @deployment_target %>
<% end %>
```

- [ ] **Step 7: Add breadcrumb to sites/edit**

In `app/views/sites/edit.erb`, add the breadcrumb above the existing `PageHeaderComponent` on line 1:

```erb
<!-- app/views/sites/edit.erb — insert at top, before existing line 1 -->
<%= render BreadcrumbComponent.new(items: [["Site"]]) %>
```

The file should start with:
```erb
<%= render BreadcrumbComponent.new(items: [["Site"]]) %>
<%= render PageHeaderComponent.new(title: t('.title')) %>
```

Note: `sites/edit.erb` has no `turbo_frame_tag` wrapper (unlike other edit views). The breadcrumb for "Site" is a single item with no link, since there is no site index within the site context.

- [ ] **Step 8: Run full test suite to check for regressions**

Run: `bundle exec rspec spec/`
Expected: All pass

- [ ] **Step 9: Commit**

```bash
git add app/views/posts/new.erb app/views/posts/edit.erb app/views/pages/new.erb app/views/pages/edit.erb app/views/books/new.erb app/views/books/edit.erb app/views/projects/new.erb app/views/projects/edit.erb app/views/deployment_targets/edit.erb app/views/sites/edit.erb
git commit -m "feat: add breadcrumbs to all edit and new views"
```

---

## Chunk 4: Mobile Responsive

### Task 11: Page Layout Responsive Padding

**Files:**
- Modify: `app/components/page_layout_component.css`

- [ ] **Step 1: Add responsive media queries**

Replace entire `app/components/page_layout_component.css`:

```css
.page-layout {
  padding: var(--space-6) var(--space-8);
  max-width: 1200px;
  margin: 0 auto;
}

@media (max-width: 768px) {
  .page-layout {
    padding: var(--space-6) var(--space-6);
  }
}

@media (max-width: 576px) {
  .page-layout {
    padding: var(--space-4) var(--space-4);
  }
}

.page-layout__content {
  /* Content area inherits spacing from parent */
}
```

- [ ] **Step 2: Commit**

```bash
git add app/components/page_layout_component.css
git commit -m "feat: responsive padding for page layout"
```

---

### Task 12: Page Header Responsive Stacking

**Files:**
- Modify: `app/components/page_header_component.css`

- [ ] **Step 1: Add flex-wrap for mobile**

Add to end of `app/components/page_header_component.css`:

```css
@media (max-width: 576px) {
  .page-header {
    flex-wrap: wrap;
    gap: var(--space-2);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/components/page_header_component.css
git commit -m "feat: responsive page header stacking on mobile"
```

---

### Task 13: List Item Responsive Actions

**Files:**
- Modify: `app/components/post_list_item_component.css`

- [ ] **Step 1: Hide action buttons on mobile**

Add to end of `app/components/post_list_item_component.css`:

```css
@media (max-width: 576px) {
  .list-row__actions {
    display: none;
  }

  .list-row__icon {
    width: 36px;
    height: 36px;
    min-width: 36px;
    font-size: 18px;
  }

  .list-row__tags {
    display: none;
  }
}
```

Note: `PostListItemComponent` and `ProjectListItemComponent` both use `.list-row__actions` — this single CSS change covers both. The entire row is already wrapped in `link_to edit_path` via `.list-row__link`, so hiding the action buttons still leaves the row clickable.

- [ ] **Step 2: Add responsive card-row CSS for PageRowComponent**

`PageRowComponent` uses `.card-row__actions` (defined in `app/components/card_row_component.css`). Unlike list-row components, `PageRowComponent` does NOT have a wrapping link — it's a plain `<div class="card-row">`. Hiding all actions would leave no way to navigate. Instead, hide only the delete and add-to-nav buttons, keeping the edit button visible.

Append to `app/components/card_row_component.css`:

```css
@media (max-width: 576px) {
  .card-row__action-btn--danger,
  .card-row__action-btn--success,
  .card-row__separator {
    display: none;
  }
}
```

This keeps the edit button (which has no modifier class) visible on mobile while hiding delete (--danger), add-to-nav (--success), and the separator.

- [ ] **Step 3: Verify manually**

1. Open the CMS in a browser
2. Resize to below 576px width
3. Check that post list and project list hide their action buttons entirely (rows still clickable via link)
4. Check that page list hides delete and add-to-nav but keeps the edit button
5. Verify clicking a post/project row still navigates to edit

- [ ] **Step 4: Commit**

```bash
git add app/components/post_list_item_component.css app/components/card_row_component.css
git commit -m "feat: hide action buttons on mobile, keep rows clickable"
```

---

### Task 14: Final Verification

- [ ] **Step 1: Run the full test suite**

Run: `bundle exec rspec spec/`
Expected: All pass

- [ ] **Step 2: Manual verification checklist**

Verify each change in the browser:

1. Navigation shows "Site" instead of "Settings"
2. Breadcrumbs appear on all edit/new views
3. Breadcrumb links navigate correctly (via Turbo)
4. Post dates display as `dd.mm.yyyy`
5. Project periods display as `mm.yyyy - mm.yyyy`
6. Book form: search OpenLibrary in edit mode works
7. Book form: cover survives validation error
8. Book: setting status to "finished" auto-fills read_at
9. Login page has no Cancel button
10. Mobile (< 576px): page padding reduced
11. Mobile (< 576px): page header title/actions stack
12. Mobile (< 576px): list row actions hidden, rows still clickable

- [ ] **Step 3: Commit any remaining fixes (if needed)**

Stage only specific files that were fixed during verification — do not use `git add -A`.
