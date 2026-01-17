# Agents.md - Development Guidelines for Meerkat CMS

## Project Overview

Feather-Page CMS is a Ruby on Rails application that provides a web interface for managing small static websites. It leverages Hugo to build static sites and provides a simple management UI.

## Design Goals

*   A simple interface that can be used by non-technical users.
*   Website should look like a real web-developer hand-coded them.
*   Deployed websites should be static.
*   Deployed websites should NOT load any external resources.
*   Deployed websites should be as small as possible.
*   Deployed websites should be SEO friendly.
*   Deployed websites are on domains that belong to the user.

## Code Quality Requirements

### Before Committing

Always run these checks before creating a commit:

```bash
bundle exec rubocop -A          # Auto-fix style issues
bundle exec rspec               # Run all tests
```

Both must pass before committing. Fix any failures before proceeding.

Also create new tests, a few feature specs for the main features and faster unit tests.

Strive for 100% code coverage and try to fix all the rubocop warning - without editing the .rubocop.yml.

## Rails Best Practices

### Controllers

- Keep controllers thin - delegate business logic to models or service objects
- Use `before_action` for shared setup (e.g., `set_post`)
- Stick to RESTful actions: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`
- Use strong parameters consistently
- Respond with appropriate status codes

```ruby
# Good
class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def create
    @post = current_site.posts.build(post_params)
    if @post.save
      redirect_to @post, notice: t('.success')
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = current_site.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :content, :slug)
  end
end
```

### Models

- Keep models focused on data integrity and associations
- Use scopes for reusable queries
- Validate at the model level
- Extract complex business logic to service objects

```ruby
# Good
class Post < ApplicationRecord
  belongs_to :site

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :site_id }

  scope :published, -> { where(draft: false).where('publish_at <= ?', Time.current) }
  scope :ordered, -> { order(publish_at: :desc) }
end
```

### Views

- Use ViewComponents instead of partials for reusable UI
- Keep ERB templates simple - no complex logic
- Use helpers for formatting
- Use I18n for all user-facing text

## Sandi Metz's Rules

Follow these rules strictly:

1. **Classes should be no longer than 100 lines**
2. **Methods should be no longer than 5 lines**
3. **Pass no more than 4 parameters** (hash options count as one)
4. **Controllers can instantiate only one object** (plus a collection for index actions)

### Breaking the Rules

You may break these rules only if you can articulate why and the reason is good.

## Robert Martin's Clean Code Principles

### Naming

- Use intention-revealing names
- Avoid mental mapping - be explicit
- Use pronounceable, searchable names
- Class names should be nouns, method names should be verbs

```ruby
# Bad
def calc(d)
  d * 1.19
end

# Good
def calculate_gross_price(net_price)
  net_price * VAT_MULTIPLIER
end
```

### Functions/Methods

- Do one thing and do it well
- Keep them small (see Sandi's 5-line rule)
- Use descriptive names
- Avoid side effects
- Command-Query Separation: methods should either do something OR answer something, not both

```ruby
# Bad - does two things
def save_and_notify(post)
  post.save
  PostMailer.notify(post).deliver_later
end

# Good - separated concerns
def save(post)
  post.save
end

def notify_about(post)
  PostMailer.notify(post).deliver_later
end
```

### Comments

- Code should be self-documenting
- Don't comment bad code - rewrite it
- Use comments only for:
  - Legal/license information
  - Explanation of intent (why, not what)
  - Warning of consequences
  - TODO markers (but clean them up)

### Error Handling

- Use exceptions rather than return codes
- Create specific exception classes when needed
- Don't return nil - use Null Objects or raise exceptions

## ViewComponents

Use ViewComponents for all reusable UI elements. They live in `app/components/`.

### Structure

```ruby
# app/components/button_component.rb
class ButtonComponent < ViewComponent::Base
  def initialize(label:, variant: :primary, size: :md)
    @label = label
    @variant = variant
    @size = size
  end

  private

  attr_reader :label, :variant, :size

  def css_classes
    ["btn", "btn-#{variant}", size_class].join(" ")
  end

  def size_class
    case size
    when :sm then "btn-sm"
    when :lg then "btn-lg"
    end
  end
end
```

```erb
<%# app/components/button_component.html.erb %>
<button class="<%= css_classes %>">
  <%= label %>
</button>
```

### Usage in Views

```erb
<%# Using the helper %>
<%= component('button', label: 'Save', variant: :primary) %>

<%# Or directly %>
<%= render ButtonComponent.new(label: 'Save') %>
```

### Guidelines

- One component per file
- Keep templates simple
- Test components in isolation
- Use slots for flexible content areas
- Prefer composition over inheritance

## Testing with RSpec

### File Structure

```
spec/
├── models/
├── controllers/
├── components/
├── requests/
├── system/
├── support/
└── factories/
```

### Writing Tests

```ruby
# spec/models/post_spec.rb
RSpec.describe Post do
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:slug) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:site) }
  end

  describe "#published?" do
    context "when post is not a draft and publish_at is in the past" do
      let(:post) { build(:post, draft: false, publish_at: 1.day.ago) }

      it "returns true" do
        expect(post).to be_published
      end
    end
  end
end
```

### Best Practices

- Use `let` and `let!` for setup
- Use factories (FactoryBot) instead of fixtures
- One assertion per test when possible
- Use descriptive context and it blocks
- Test behavior, not implementation

## Git Commit Guidelines

### Commit Message Format

```
<type>: <subject>

<body>

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `style`: Formatting, missing semicolons, etc.
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `chore`: Maintenance tasks

### Rules

1. **Atomic commits**: Each commit should represent one logical change
2. **Run tests before committing**: Never commit failing tests
3. **Write meaningful messages**: Explain why, not what
4. **Keep commits small**: Easier to review and revert if needed

### Examples

```bash
# Good
feat: Add dark mode toggle to navigation

Implements theme switching with localStorage persistence.
Respects system preference as default.

# Bad
update stuff
fix
wip
```

## Rubocop Configuration

The project uses Rubocop for style enforcement. Key rules:

- Max line length: 120 characters
- Use Ruby 3.x syntax
- Prefer double quotes for strings
- Use trailing commas in multi-line collections

Run with auto-correct:

```bash
bundle exec rubocop -A
```

## Development Workflow

1. **Before starting work**:
   ```bash
   git pull origin main
   bundle install
   ```

2. **During development**:
   - Write tests first (TDD) when possible
   - Run `bundle exec rspec` frequently
   - Run `bundle exec rubocop -A` to fix style issues

3. **Before committing**:
   ```bash
   bundle exec rubocop -A
   bundle exec rspec
   git add -p  # Review changes
   git commit
   ```

4. **Commit message**:
   - Use the format described above
   - Reference issues if applicable

## Directory Structure

```
app/
├── components/          # ViewComponents
│   └── form/           # Form-related components
├── controllers/
├── helpers/
├── javascript/
│   └── controllers/    # Stimulus controllers
├── models/
├── services/           # Service objects
└── views/
    └── layouts/
```

## Summary Checklist

Before every commit, verify:

- [ ] `bundle exec rubocop -A` passes
- [ ] `bundle exec rspec` passes
- [ ] Commit message follows format
- [ ] Changes are atomic and focused
- [ ] No debugging code left behind
- [ ] I18n used for user-facing text
- [ ] ViewComponents used for reusable UI
