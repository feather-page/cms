# Lists & Cards Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all table-based and card-based content listings in the CMS admin with modern list-rows, a visual bookshelf, and empty states.

**Architecture:** New ViewComponent classes replace existing ERB partials and table markup. Each component gets an RSpec test and a Lookbook preview. Styling goes into `application.scss`. All changes are CMS admin only — `static_site/` components are untouched.

**Tech Stack:** Rails 8.1, ViewComponent, RSpec, FactoryBot, Lookbook, Bootstrap 5.3, Stimulus, Turbo

**Spec:** `docs/superpowers/specs/2026-03-15-lists-and-cards-redesign.md`

---

## Chunk 1: Foundation — Lookbook Setup + EmptyStateComponent

### Task 1: Add Lookbook to the project

Lookbook is not yet in the main branch Gemfile or routes. It needs to be added before any preview work.

**Files:**
- Modify: `Gemfile`
- Modify: `config/routes.rb`
- Create: `spec/components/previews/.keep`
- Modify: `config/application.rb` (configure preview path)

- [ ] **Step 1: Add Lookbook gem to Gemfile**

Add to the development group in `Gemfile`:

```ruby
gem "lookbook"
```

- [ ] **Step 2: Bundle install**

Run: `bundle install`

- [ ] **Step 3: Mount Lookbook in routes**

Add to `config/routes.rb` inside `Rails.application.routes.draw do`, before any other routes:

```ruby
mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
```

- [ ] **Step 4: Create previews directory and configure path**

Run: `mkdir -p spec/components/previews`

Add to `config/application.rb` inside the `Application` class:

```ruby
config.view_component.preview_paths << Rails.root.join("spec/components/previews")
```

- [ ] **Step 5: Verify Lookbook loads**

Run: `bin/rails server` and visit `http://localhost:3000/lookbook`
Expected: Lookbook UI loads (empty, no previews yet)

- [ ] **Step 6: Commit**

```bash
git add Gemfile Gemfile.lock config/routes.rb spec/components/previews/.keep
git commit -m "Add Lookbook gem and mount engine for component previews"
```

---

### Task 2: Create EmptyStateComponent

The simplest component — no model dependencies. Used across all list views.

**Files:**
- Create: `app/components/empty_state_component.rb`
- Create: `app/components/empty_state_component.html.erb`
- Create: `spec/components/empty_state_component_spec.rb`
- Create: `spec/components/previews/empty_state_component_preview.rb`
- Modify: `app/assets/stylesheets/application.scss`

- [ ] **Step 1: Write the failing test**

Create `spec/components/empty_state_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmptyStateComponent, type: :component do
  it "renders emoji, headline, and CTA button" do
    render_inline(described_class.new(
      emoji: "✏️",
      headline: "Noch keine Blogposts",
      cta_text: "Neuer Post",
      cta_path: "/posts/new"
    ))

    expect(page).to have_text("✏️")
    expect(page).to have_text("Noch keine Blogposts")
    expect(page).to have_link("Neuer Post", href: "/posts/new")
  end

  it "renders optional subtitle" do
    render_inline(described_class.new(
      emoji: "📚",
      headline: "Dein Buecherregal ist leer",
      subtitle: "Fuege dein erstes Buch hinzu.",
      cta_text: "Neues Buch",
      cta_path: "/books/new"
    ))

    expect(page).to have_text("Fuege dein erstes Buch hinzu.")
  end

  it "renders without subtitle" do
    render_inline(described_class.new(
      emoji: "📄",
      headline: "Keine Seiten",
      cta_text: "Neue Seite",
      cta_path: "/pages/new"
    ))

    expect(page).not_to have_css(".empty-state__subtitle")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/components/empty_state_component_spec.rb`
Expected: FAIL — `uninitialized constant EmptyStateComponent`

- [ ] **Step 3: Write the component class**

Create `app/components/empty_state_component.rb`:

```ruby
# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  def initialize(emoji:, headline:, cta_text:, cta_path:, subtitle: nil)
    @emoji = emoji
    @headline = headline
    @subtitle = subtitle
    @cta_text = cta_text
    @cta_path = cta_path
  end
end
```

- [ ] **Step 4: Write the template**

Create `app/components/empty_state_component.html.erb`:

```erb
<div class="empty-state">
  <div class="empty-state__emoji"><%= @emoji %></div>
  <h3 class="empty-state__headline"><%= @headline %></h3>
  <% if @subtitle %>
    <p class="empty-state__subtitle"><%= @subtitle %></p>
  <% end %>
  <%= link_to @cta_text, @cta_path, class: "btn btn-primary" %>
</div>
```

- [ ] **Step 5: Add styles**

Append to `app/assets/stylesheets/application.scss`:

```scss
// Empty State Component
.empty-state {
  text-align: center;
  padding: 48px 24px;

  &__emoji {
    font-size: 48px;
    margin-bottom: 12px;
  }

  &__headline {
    font-size: 15px;
    font-weight: 500;
    color: var(--color-text-primary, #3d3832);
    margin-bottom: 4px;
  }

  &__subtitle {
    font-size: 13px;
    color: var(--color-text-muted, #9a938a);
    margin-bottom: 0;
  }

  .btn {
    margin-top: 16px;
  }
}
```

- [ ] **Step 6: Run tests**

Run: `bundle exec rspec spec/components/empty_state_component_spec.rb`
Expected: All 3 tests PASS

- [ ] **Step 7: Create Lookbook preview**

Create `spec/components/previews/empty_state_component_preview.rb`:

```ruby
# frozen_string_literal: true

class EmptyStateComponentPreview < Lookbook::Preview
  # @label Posts
  def posts
    render EmptyStateComponent.new(
      emoji: "✏️",
      headline: "Noch keine Blogposts",
      subtitle: "Schreibe deinen ersten Post und teile ihn mit der Welt.",
      cta_text: "Neuer Post",
      cta_path: "#"
    )
  end

  # @label Books
  def books
    render EmptyStateComponent.new(
      emoji: "📚",
      headline: "Dein Buecherregal ist leer",
      subtitle: "Fuege dein erstes Buch hinzu.",
      cta_text: "Neues Buch",
      cta_path: "#"
    )
  end

  # @label Pages
  def pages
    render EmptyStateComponent.new(
      emoji: "📄",
      headline: "Keine Seiten vorhanden",
      subtitle: "Erstelle Seiten wie Impressum, About oder Kontakt.",
      cta_text: "Neue Seite",
      cta_path: "#"
    )
  end

  # @label Projects
  def projects
    render EmptyStateComponent.new(
      emoji: "🏗️",
      headline: "Keine Projekte",
      subtitle: "Zeige deine Arbeit und Projekte.",
      cta_text: "Neues Projekt",
      cta_path: "#"
    )
  end

  # @label Invitations
  def invitations
    render EmptyStateComponent.new(
      emoji: "✉️",
      headline: "Keine ausstehenden Einladungen",
      subtitle: "Lade weitere Nutzer ein, um an deiner Seite mitzuarbeiten.",
      cta_text: "Nutzer einladen",
      cta_path: "#"
    )
  end
end
```

- [ ] **Step 8: Verify in Lookbook**

Visit `http://localhost:3000/lookbook` and check all 5 preview variants render correctly.

- [ ] **Step 9: Commit**

```bash
git add app/components/empty_state_component* spec/components/empty_state_component_spec.rb spec/components/previews/empty_state_component_preview.rb app/assets/stylesheets/application.scss
git commit -m "Add EmptyStateComponent with tests and Lookbook previews"
```

---

## Chunk 2: PostListItemComponent

### Task 3: Create PostListItemComponent

Replaces `app/views/posts/_post.erb`. Each post rendered as a horizontal list-row.

**Files:**
- Create: `app/components/post_list_item_component.rb`
- Create: `app/components/post_list_item_component.html.erb`
- Create: `spec/components/post_list_item_component_spec.rb`
- Create: `spec/components/previews/post_list_item_component_preview.rb`
- Modify: `app/assets/stylesheets/application.scss`

- [ ] **Step 1: Write the failing test**

Create `spec/components/post_list_item_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostListItemComponent, type: :component do
  let(:site) { create(:site) }

  describe "titled post" do
    let(:post) { create(:post, site: site, title: "My Great Post", emoji: "🔔") }

    it "renders title and emoji" do
      render_inline(described_class.new(post: post))

      expect(page).to have_text("My Great Post")
      expect(page).to have_text("🔔")
    end

    it "links to edit path" do
      render_inline(described_class.new(post: post))

      expect(page).to have_link(href: /posts\/#{post.public_id}/)
    end
  end

  describe "short post (no title)" do
    let(:post) { create(:post, site: site, title: nil, content: [{ "type" => "paragraph", "data" => { "text" => "This is a short post without a title, just some content text." } }]) }

    it "renders content excerpt instead of title" do
      render_inline(described_class.new(post: post))

      expect(page).to have_text("This is a short post")
    end
  end

  describe "draft post" do
    let(:post) { create(:post, site: site, draft: true) }

    it "shows draft badge" do
      render_inline(described_class.new(post: post))

      expect(page).to have_text("Draft")
    end
  end

  describe "published post" do
    let(:post) { create(:post, site: site, draft: false) }

    it "shows published badge" do
      render_inline(described_class.new(post: post))

      expect(page).to have_text("Published")
    end
  end

  describe "tagged post" do
    let(:post) { create(:post, :tagged, site: site) }

    it "renders tag pills" do
      render_inline(described_class.new(post: post))

      expect(page).to have_css(".list-row__tag")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/components/post_list_item_component_spec.rb`
Expected: FAIL — `uninitialized constant PostListItemComponent`

- [ ] **Step 3: Write the component class**

Create `app/components/post_list_item_component.rb`:

```ruby
# frozen_string_literal: true

class PostListItemComponent < ViewComponent::Base
  def initialize(post:)
    @post = post
  end

  def short_post?
    @post.title.blank?
  end

  def display_text
    if short_post?
      @post.content_excerpt(length: 120)
    else
      @post.title
    end
  end

  def status_badge_class
    @post.draft? ? "list-row__badge--draft" : "list-row__badge--published"
  end

  def status_label
    @post.draft? ? "Draft" : "Published"
  end

  def icon_content
    if @post.thumbnail_image&.file&.attached?
      helpers.image_tag(@post.thumbnail_image.file.variant(:mobile_x1_webp),
                        class: "list-row__thumbnail")
    elsif @post.emoji.present?
      content_tag(:span, @post.emoji, class: "list-row__emoji")
    elsif short_post?
      helpers.icon("chat-left-text")
    else
      helpers.icon("file-text")
    end
  end

  def edit_path
    helpers.edit_site_post_path(@post.site, @post)
  end

  def formatted_date
    @post.publish_at&.strftime("%-d. %b %Y")
  end
end
```

- [ ] **Step 4: Write the template**

Create `app/components/post_list_item_component.html.erb`:

```erb
<%= link_to edit_path, class: "list-row", data: { turbo_frame: "_top" } do %>
  <div class="list-row__icon">
    <%= icon_content %>
  </div>
  <div class="list-row__content">
    <div class="list-row__title <%= 'list-row__title--short' if short_post? %>">
      <%= display_text %>
    </div>
    <div class="list-row__meta">
      <span><%= formatted_date %></span>
      <span class="list-row__badge <%= status_badge_class %>"><%= status_label %></span>
    </div>
  </div>
  <% if @post.tag_list.any? %>
    <div class="list-row__tags">
      <% @post.tag_list.first(3).each do |tag| %>
        <span class="list-row__tag"><%= tag %></span>
      <% end %>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 5: Add styles**

Append to `app/assets/stylesheets/application.scss`:

```scss
// List Row Component (shared base for Posts, Users, DeploymentTargets, Projects)
.list-row {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid var(--color-border, #e0d8cf);
  gap: 12px;
  text-decoration: none;
  color: inherit;
  transition: background-color 0.15s ease;

  &:hover {
    background-color: var(--color-bg-hover, #faf8f5);
    text-decoration: none;
    color: inherit;
  }

  &__icon {
    width: 48px;
    height: 48px;
    min-width: 48px;
    border-radius: 8px;
    background: var(--color-bg-muted, #f0e6dc);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    overflow: hidden;
  }

  &__thumbnail {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  &__emoji {
    font-size: 24px;
  }

  &__content {
    flex: 1;
    min-width: 0;
  }

  &__title {
    font-weight: 600;
    font-size: 14px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;

    &--short {
      font-weight: 400;
      white-space: normal;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
  }

  &__meta {
    font-size: 12px;
    color: var(--color-text-muted, #9a938a);
    margin-top: 2px;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  &__badge {
    padding: 1px 8px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 500;

    &--published {
      background: #d4edda;
      color: #3d7a3d;
    }

    &--draft {
      background: #fff3cd;
      color: #856404;
    }
  }

  &__tags {
    display: flex;
    gap: 6px;
    flex-shrink: 0;
  }

  &__tag {
    background: var(--color-bg-muted, #f0e6dc);
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    color: var(--color-text-secondary, #5c564e);
  }
}
```

- [ ] **Step 6: Run tests**

Run: `bundle exec rspec spec/components/post_list_item_component_spec.rb`
Expected: All tests PASS

- [ ] **Step 7: Create Lookbook preview**

Create `spec/components/previews/post_list_item_component_preview.rb`:

```ruby
# frozen_string_literal: true

class PostListItemComponentPreview < Lookbook::Preview
  # @label With Title and Emoji
  def with_title_and_emoji
    post = FactoryBot.build_stubbed(:post, title: "Book review: Atlas Shrugged", emoji: "🔔", draft: false, publish_at: 2.days.ago)
    render PostListItemComponent.new(post: post)
  end

  # @label Short Post (no title)
  def short_post
    post = FactoryBot.build_stubbed(:post, title: nil, content: [{ "type" => "paragraph", "data" => { "text" => "I'm really happy with my new job as a developer at CONSUST! I get to spend my time building features that help companies deal with their carbon footprint." } }], draft: false, publish_at: 3.days.ago)
    render PostListItemComponent.new(post: post)
  end

  # @label Draft Post
  def draft
    post = FactoryBot.build_stubbed(:post, title: "Work in Progress Article", draft: true, publish_at: Time.current)
    render PostListItemComponent.new(post: post)
  end

  # @label With Tags
  def with_tags
    post = FactoryBot.build_stubbed(:post, title: "Ruby on Rails Tips", emoji: "💎", tags: "ruby, rails, web", draft: false, publish_at: 1.week.ago)
    render PostListItemComponent.new(post: post)
  end
end
```

- [ ] **Step 8: Verify in Lookbook**

Visit `http://localhost:3000/lookbook` and check all 4 post variants render correctly.

- [ ] **Step 9: Integrate into posts index**

Modify `app/views/posts/index.erb` — replace the existing post partial rendering with the new component. Keep the page header and "New Post" button. Add EmptyStateComponent for empty lists.

- [ ] **Step 10: Run full test suite for posts**

Run: `bundle exec rspec spec/components/post_list_item_component_spec.rb spec/requests/`
Expected: All tests PASS

- [ ] **Step 11: Commit**

```bash
git add app/components/post_list_item_component* spec/components/post_list_item_component_spec.rb spec/components/previews/post_list_item_component_preview.rb app/views/posts/index.erb app/assets/stylesheets/application.scss
git commit -m "Replace post cards with PostListItemComponent list-rows"
```

---

## Chunk 3: BookshelfComponent + BookCoverComponent

### Task 4: Create BookCoverComponent

The individual book cover tile — used inside the bookshelf.

**Files:**
- Create: `app/components/book_cover_component.rb`
- Create: `app/components/book_cover_component.html.erb`
- Create: `spec/components/book_cover_component_spec.rb`
- Create: `spec/components/previews/book_cover_component_preview.rb`
- Modify: `app/assets/stylesheets/application.scss`

- [ ] **Step 1: Write the failing test**

Create `spec/components/book_cover_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookCoverComponent, type: :component do
  let(:site) { create(:site) }

  describe "finished book with rating" do
    let(:book) { create(:book, site: site, title: "Othello", author: "Shakespeare", rating: 4, reading_status: :finished) }

    it "renders title and author" do
      render_inline(described_class.new(book: book))

      expect(page).to have_text("Othello")
      expect(page).to have_text("Shakespeare")
    end

    it "renders star rating" do
      render_inline(described_class.new(book: book))

      expect(page).to have_css(".book-cover__rating")
    end
  end

  describe "book without cover" do
    let(:book) { create(:book, site: site, emoji: "📕") }

    it "renders emoji fallback" do
      render_inline(described_class.new(book: book))

      expect(page).to have_text("📕")
    end
  end

  describe "want-to-read book" do
    let(:book) { create(:book, :want_to_read, site: site) }

    it "does not render rating" do
      render_inline(described_class.new(book: book))

      expect(page).not_to have_css(".book-cover__rating")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/components/book_cover_component_spec.rb`
Expected: FAIL

- [ ] **Step 3: Write the component**

Create `app/components/book_cover_component.rb`:

```ruby
# frozen_string_literal: true

class BookCoverComponent < ViewComponent::Base
  def initialize(book:)
    @book = book
  end

  def cover_image?
    @book.cover_image&.file&.attached?
  end

  def show_rating?
    @book.finished? && @book.rating.present? && @book.rating > 0
  end

  def star_rating
    "★" * @book.rating + "☆" * (5 - @book.rating)
  end

  def edit_path
    helpers.edit_book_path(@book)
  end

  def emoji_or_fallback
    @book.emoji.presence || "📖"
  end
end
```

Create `app/components/book_cover_component.html.erb`:

```erb
<%= link_to edit_path, class: "book-cover", title: "#{@book.title} – #{@book.author}" do %>
  <div class="book-cover__image">
    <% if cover_image? %>
      <%= image_tag @book.cover_image.file.variant(:mobile_x1_webp), class: "book-cover__img" %>
    <% else %>
      <span class="book-cover__emoji"><%= emoji_or_fallback %></span>
    <% end %>
  </div>
  <div class="book-cover__title"><%= truncate(@book.title, length: 30) %></div>
  <div class="book-cover__author"><%= truncate(@book.author, length: 25) %></div>
  <% if show_rating? %>
    <div class="book-cover__rating"><%= star_rating %></div>
  <% end %>
<% end %>
```

- [ ] **Step 4: Add styles**

Append to `app/assets/stylesheets/application.scss`:

```scss
// Book Cover Component
.book-cover {
  width: 72px;
  text-align: center;
  text-decoration: none;
  color: inherit;
  display: inline-block;

  &:hover {
    text-decoration: none;
    color: inherit;

    .book-cover__image {
      transform: scale(1.05);
      box-shadow: 3px 3px 12px rgba(0, 0, 0, 0.2);
    }
  }

  &__image {
    width: 72px;
    height: 104px;
    border-radius: 3px;
    box-shadow: 2px 2px 8px rgba(0, 0, 0, 0.15);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--color-bg-muted, #e8e0d5);
    transition: transform 0.15s ease, box-shadow 0.15s ease;
  }

  &__img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  &__emoji {
    font-size: 28px;
  }

  &__title {
    font-size: 11px;
    font-weight: 500;
    margin-top: 4px;
    line-height: 1.3;
  }

  &__author {
    font-size: 10px;
    color: var(--color-text-muted, #9a938a);
  }

  &__rating {
    font-size: 10px;
    color: #d4a03a;
    margin-top: 2px;
  }
}
```

- [ ] **Step 5: Run tests**

Run: `bundle exec rspec spec/components/book_cover_component_spec.rb`
Expected: All PASS

- [ ] **Step 6: Create Lookbook preview**

Create `spec/components/previews/book_cover_component_preview.rb`:

```ruby
# frozen_string_literal: true

class BookCoverComponentPreview < Lookbook::Preview
  # @label Finished with Rating
  def finished_with_rating
    book = FactoryBot.build_stubbed(:book, title: "Othello", author: "Shakespeare", rating: 4, emoji: "📕", reading_status: :finished)
    render BookCoverComponent.new(book: book)
  end

  # @label Want to Read
  def want_to_read
    book = FactoryBot.build_stubbed(:book, :want_to_read, title: "1984", author: "Orwell", emoji: "📚")
    render BookCoverComponent.new(book: book)
  end

  # @label Currently Reading
  def currently_reading
    book = FactoryBot.build_stubbed(:book, :reading, title: "On Liberty", author: "J.S. Mill", emoji: "📖")
    render BookCoverComponent.new(book: book)
  end

  # @label No Rating
  def no_rating
    book = FactoryBot.build_stubbed(:book, title: "Gil Blas", author: "Le Sage", rating: nil, emoji: "📙", reading_status: :finished)
    render BookCoverComponent.new(book: book)
  end
end
```

- [ ] **Step 7: Commit**

```bash
git add app/components/book_cover_component* spec/components/book_cover_component_spec.rb spec/components/previews/book_cover_component_preview.rb app/assets/stylesheets/application.scss
git commit -m "Add BookCoverComponent with tests and Lookbook previews"
```

---

### Task 5: Create BookshelfComponent

The container that groups books into sections: Currently Reading, Want to Read, then finished books by year.

**Files:**
- Create: `app/components/bookshelf_component.rb`
- Create: `app/components/bookshelf_component.html.erb`
- Create: `spec/components/bookshelf_component_spec.rb`
- Create: `spec/components/previews/bookshelf_component_preview.rb`
- Modify: `app/assets/stylesheets/application.scss`

- [ ] **Step 1: Write the failing test**

Create `spec/components/bookshelf_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookshelfComponent, type: :component do
  let(:site) { create(:site) }

  it "groups books into currently reading section" do
    create(:book, :reading, site: site, title: "Current Book")

    render_inline(described_class.new(books: site.books, site: site))

    expect(page).to have_text("Currently Reading")
    expect(page).to have_text("Current Book")
  end

  it "groups books into want to read section" do
    create(:book, :want_to_read, site: site, title: "Future Book")

    render_inline(described_class.new(books: site.books, site: site))

    expect(page).to have_text("Want to Read")
    expect(page).to have_text("Future Book")
  end

  it "groups finished books by year" do
    create(:book, site: site, title: "Old Book", read_at: Date.new(2025, 6, 15), reading_status: :finished)
    create(:book, site: site, title: "New Book", read_at: Date.new(2026, 1, 10), reading_status: :finished)

    render_inline(described_class.new(books: site.books, site: site))

    expect(page).to have_text("2026")
    expect(page).to have_text("2025")
  end

  it "shows empty state when no books" do
    render_inline(described_class.new(books: site.books, site: site))

    expect(page).to have_text("Dein Buecherregal ist leer")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/components/bookshelf_component_spec.rb`
Expected: FAIL

- [ ] **Step 3: Write the component**

Create `app/components/bookshelf_component.rb`:

```ruby
# frozen_string_literal: true

class BookshelfComponent < ViewComponent::Base
  def initialize(books:, site:)
    @books = books
    @site = site
  end

  def currently_reading
    @currently_reading ||= @books.where(reading_status: :reading).order(created_at: :desc)
  end

  def want_to_read
    @want_to_read ||= @books.where(reading_status: :want_to_read).order(created_at: :desc)
  end

  def finished_by_year
    @finished_by_year ||= @books
      .where(reading_status: :finished)
      .order(read_at: :desc)
      .group_by { |book| book.read_at&.year }
      .sort_by { |year, _| -(year || 0) }
  end

  def empty?
    @books.none?
  end

  def new_book_path
    helpers.new_site_book_path(@site)
  end

  def average_rating(books)
    rated = books.select { |b| b.rating.present? && b.rating > 0 }
    return nil if rated.empty?

    avg = rated.sum(&:rating).to_f / rated.size
    "★" * avg.round + "☆" * (5 - avg.round)
  end
end
```

Create `app/components/bookshelf_component.html.erb`:

```erb
<% if empty? %>
  <%= render EmptyStateComponent.new(
    emoji: "📚",
    headline: "Dein Buecherregal ist leer",
    subtitle: "Fuege dein erstes Buch hinzu.",
    cta_text: "Neues Buch",
    cta_path: new_book_path
  ) %>
<% else %>
  <%# Currently Reading %>
  <% if currently_reading.any? %>
    <div class="bookshelf__section">
      <div class="bookshelf__section-header">
        <span class="bookshelf__dot bookshelf__dot--reading"></span>
        Currently Reading · <%= currently_reading.size %>
      </div>
      <div class="bookshelf__grid">
        <% currently_reading.each do |book| %>
          <%= render BookCoverComponent.new(book: book) %>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Want to Read %>
  <% if want_to_read.any? %>
    <div class="bookshelf__section">
      <div class="bookshelf__section-header">
        <span class="bookshelf__dot bookshelf__dot--want"></span>
        Want to Read · <%= want_to_read.size %>
      </div>
      <div class="bookshelf__grid">
        <% want_to_read.each do |book| %>
          <%= render BookCoverComponent.new(book: book) %>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Finished by year %>
  <% finished_by_year.each_with_index do |(year, books), index| %>
    <div class="bookshelf__year" data-controller="toggle" data-toggle-open-value="<%= index == 0 %>">
      <div class="bookshelf__year-header" data-action="click->toggle#toggle">
        <div class="bookshelf__year-title">
          <span data-toggle-target="icon" class="bookshelf__chevron">▶</span>
          <%= year || "Unknown" %>
        </div>
        <span class="bookshelf__year-stats">
          <%= books.size %> <%= books.size == 1 ? "Buch" : "Bücher" %>
          <% if (avg = average_rating(books)) %>
            · ⌀ <%= avg %>
          <% end %>
        </span>
      </div>
      <div class="bookshelf__grid" data-toggle-target="content">
        <% books.each do |book| %>
          <%= render BookCoverComponent.new(book: book) %>
        <% end %>
      </div>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 4: Add styles and Stimulus controller**

Append to `app/assets/stylesheets/application.scss`:

```scss
// Bookshelf Component
.bookshelf {
  &__section {
    margin-bottom: 24px;
  }

  &__section-header {
    font-weight: 600;
    font-size: 14px;
    color: var(--color-text-muted, #9a938a);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 12px;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  &__dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;

    &--reading { background: #d4a03a; }
    &--want { background: #9a938a; }
  }

  &__grid {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
  }

  &__year {
    margin-bottom: 16px;
    border-top: 1px solid var(--color-border, #e0d8cf);
    padding-top: 12px;
  }

  &__year-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    cursor: pointer;
    margin-bottom: 12px;
  }

  &__year-title {
    font-weight: 700;
    font-size: 18px;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  &__chevron {
    font-size: 12px;
    transition: transform 0.2s ease;

    .bookshelf__year[data-toggle-open-value="true"] & {
      transform: rotate(90deg);
    }
  }

  &__year-stats {
    font-size: 13px;
    color: var(--color-text-muted, #9a938a);
  }
}
```

Create `app/javascript/controllers/toggle_controller.js` (if not already existing):

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { open: { type: Boolean, default: true } }

  connect() {
    this.render()
  }

  toggle() {
    this.openValue = !this.openValue
    this.render()
  }

  render() {
    if (this.hasContentTarget) {
      this.contentTarget.style.display = this.openValue ? "flex" : "none"
    }
    if (this.hasIconTarget) {
      this.iconTarget.textContent = this.openValue ? "▼" : "▶"
    }
  }
}
```

- [ ] **Step 5: Run tests**

Run: `bundle exec rspec spec/components/bookshelf_component_spec.rb`
Expected: All PASS

- [ ] **Step 6: Create Lookbook preview**

Create `spec/components/previews/bookshelf_component_preview.rb`:

```ruby
# frozen_string_literal: true

class BookshelfComponentPreview < Lookbook::Preview
  # @label With Books
  def with_books
    site = Site.first || FactoryBot.create(:site)
    render BookshelfComponent.new(books: site.books, site: site)
  end

  # @label Empty
  def empty
    site = FactoryBot.create(:site)
    render BookshelfComponent.new(books: site.books, site: site)
  end
end
```

- [ ] **Step 7: Modify BooksController to load all books**

The current controller filters books by `reading_status` param (tab-based). The BookshelfComponent does its own grouping, so the controller must load ALL books for the site. Modify `app/controllers/books_controller.rb` — the `index` action should set `@books = policy_scope(Book)` without status filtering.

- [ ] **Step 8: Integrate into books index**

Modify `app/views/books/index.erb` — replace existing table/tabs with `render BookshelfComponent.new(books: @books, site: current_site)`. Keep page header and "New Book" button.

- [ ] **Step 9: Run full test suite**

Run: `bundle exec rspec spec/components/book_cover_component_spec.rb spec/components/bookshelf_component_spec.rb`
Expected: All PASS

- [ ] **Step 10: Commit**

```bash
git add app/components/bookshelf_component* app/components/book_cover_component* spec/components/bookshelf_component_spec.rb spec/components/previews/bookshelf_component_preview.rb app/views/books/index.erb app/assets/stylesheets/application.scss app/javascript/controllers/toggle_controller.js
git commit -m "Replace books table with visual BookshelfComponent"
```

---

## Chunk 4: Pages, Deployment Targets, Users, Projects

### Task 6: Create NavigationItemRowComponent and PageRowComponent

**Files:**
- Create: `app/components/navigation_item_row_component.rb`
- Create: `app/components/navigation_item_row_component.html.erb`
- Create: `app/components/page_row_component.rb`
- Create: `app/components/page_row_component.html.erb`
- Create: `spec/components/navigation_item_row_component_spec.rb`
- Create: `spec/components/page_row_component_spec.rb`
- Create: `spec/components/previews/navigation_item_row_component_preview.rb`
- Create: `spec/components/previews/page_row_component_preview.rb`
- Modify: `app/assets/stylesheets/application.scss`
- Modify: `app/views/pages/index.erb`
- Modify: `app/components/navigation_component.html.erb`

- [ ] **Step 1: Write tests for NavigationItemRowComponent**

Test that it renders title, slug, up/down arrows, edit link, and remove button. Test that `first?` disables up arrow, `last?` disables down arrow.

- [ ] **Step 2: Implement NavigationItemRowComponent**

Card-style row with drag handle, icon (page emoji or fallback), title + slug, action buttons (up/down | edit/remove). Use 28x28 icon buttons with separators.

- [ ] **Step 3: Write tests for PageRowComponent**

Test that it renders title, slug, "add to nav" button, edit link, and delete button with confirmation.

- [ ] **Step 4: Implement PageRowComponent**

Same card style as NavigationItemRowComponent. Buttons: plus (add to nav) | edit / trash.

- [ ] **Step 5: Add card-row styles**

```scss
.card-row { /* border, border-radius 8px, white bg, flex layout, gap, padding */ }
.card-row__actions { /* flex, gap 4px, icon buttons 28x28 */ }
.card-row__separator { /* 1px border, 20px height */ }
.card-row__action-btn { /* 28x28, border, border-radius 4px */ }
.card-row__action-btn--danger { /* red-tinted border */ }
.card-row__action-btn--success { /* green-tinted border */ }
.card-row__drag-handle { /* cursor grab, color muted */ }
```

- [ ] **Step 6: Create Lookbook previews for both components**

- [ ] **Step 7: Integrate into pages index and NavigationComponent**

Replace tables in `app/views/pages/index.erb` with the new components. Add EmptyStateComponent for empty page lists. Update `app/components/navigation_component.html.erb` to use `NavigationItemRowComponent`.

- [ ] **Step 8: Run tests and commit**

```bash
git commit -m "Replace pages tables with NavigationItemRowComponent and PageRowComponent"
```

---

### Task 7: Create DeploymentTargetRowComponent

**Files:**
- Create: `app/components/deployment_target_row_component.rb`
- Create: `app/components/deployment_target_row_component.html.erb`
- Create: `spec/components/deployment_target_row_component_spec.rb`
- Create: `spec/components/previews/deployment_target_row_component_preview.rb`
- Modify: `app/views/deployment_targets/index.erb`

- [ ] **Step 1: Write tests** — renders hostname, type, Deploy (primary) and Preview (secondary) buttons. Icon color differs by type (green for production, amber for staging).

- [ ] **Step 2: Implement component** — uses shared `.list-row` base styles. Deploy button gets `btn btn-primary`, Preview gets `btn btn-outline-secondary`.

- [ ] **Step 3: Create Lookbook preview** — production and staging variants.

- [ ] **Step 4: Integrate into deployment targets index**

- [ ] **Step 5: Run tests and commit**

```bash
git commit -m "Replace deployment targets table with DeploymentTargetRowComponent"
```

---

### Task 8: Create SiteUserRowComponent

**Files:**
- Create: `app/components/site_user_row_component.rb`
- Create: `app/components/site_user_row_component.html.erb`
- Create: `spec/components/site_user_row_component_spec.rb`
- Create: `spec/components/previews/site_user_row_component_preview.rb`
- Modify: `app/views/site_users/index.erb`

- [ ] **Step 1: Write tests** — renders email, user icon. Does not show delete for current user.

- [ ] **Step 2: Implement component** — uses `.list-row` base. User icon (40x40) + email. Pending invitations section with labeled divider.

- [ ] **Step 3: Create Lookbook preview** — user and invitation variants.

- [ ] **Step 4: Integrate into site_users index** — add EmptyStateComponent for empty invitations.

- [ ] **Step 5: Run tests and commit**

```bash
git commit -m "Replace users table with SiteUserRowComponent"
```

---

### Task 9: Create ProjectListItemComponent

**Files:**
- Create: `app/components/project_list_item_component.rb`
- Create: `app/components/project_list_item_component.html.erb`
- Create: `spec/components/project_list_item_component_spec.rb`
- Create: `spec/components/previews/project_list_item_component_preview.rb`
- Modify: `app/views/projects/index.erb`

- [ ] **Step 1: Write tests** — renders title, company, role, status badge, emoji icon.

- [ ] **Step 2: Implement component** — uses `.list-row` base. Emoji icon (48x48) + title + company/role meta + status badge.

- [ ] **Step 3: Create Lookbook preview** — completed, ongoing, personal project variants.

- [ ] **Step 4: Integrate into projects index** — add EmptyStateComponent for empty list.

- [ ] **Step 5: Run tests and commit**

```bash
git commit -m "Replace projects listing with ProjectListItemComponent"
```

---

## Chunk 5: Cleanup and Final Verification

### Task 10: Remove old partials and clean up CSS

- [ ] **Step 1: Remove replaced partials**

Delete the old files that are no longer used:
- `app/views/posts/_post.erb` (replaced by PostListItemComponent)
- `app/views/books/_book.erb` (replaced by BookCoverComponent)
- `app/views/pages/_page.erb` (replaced by PageRowComponent)
- `app/views/pages/_pages.erb` (replaced by inline rendering)
- `app/views/site_users/_site_user.erb` (replaced by SiteUserRowComponent)
- `app/views/projects/_project.erb` (replaced by ProjectListItemComponent)

Only delete after verifying each view works with the new component.

- [ ] **Step 2: Clean up unused CSS**

Remove old CSS classes from `application.scss` that are no longer needed:
- `.post-card` and related styles
- Old table-specific styling that was only used by the replaced views

Do NOT remove `.table` base styles or Bootstrap utilities — other parts of the app may still use them.

- [ ] **Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS

- [ ] **Step 4: Manual smoke test**

Start the server and manually verify each view:
1. Posts index — list-rows render, short-posts look correct, empty state works
2. Books index — bookshelf renders, year collapsing works, empty state works
3. Pages index — navigation items with up/down/remove, other pages with add-to-nav
4. Deployment targets — rows with Deploy/Preview buttons
5. Users — user rows with invitation section
6. Projects — project rows with status badges
7. Lookbook — all previews render at `/lookbook`

- [ ] **Step 5: Commit cleanup**

```bash
git commit -m "Remove old partials and unused CSS after lists-and-cards migration"
```
