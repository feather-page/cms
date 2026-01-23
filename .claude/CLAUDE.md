# Instructions for AI Agents

**Project Stack:** Rails 8.1, Ruby 4.0.1, PostgreSQL 17

**Key Libraries:** LightService (interactions), ViewComponent, Import Maps, Sidekiq, Kamal

---

## 🎯 Design Goals

This is a CMS for static websites. All decisions must align with these goals:

1. **Simple interface** – Usable by non-technical users
2. **Professional output** – Sites should look hand-coded by a web developer
3. **Static deployment** – Generated sites are pure static HTML/CSS
4. **No external resources** – Deployed sites must NOT load external resources
5. **Minimal size** – Deployed sites should be as small as possible
6. **SEO friendly** – Proper meta tags, semantic HTML, fast loading
7. **User domains** – Sites deploy to domains owned by the user

When implementing features, always ask: *Does this align with these goals?*

---

## ⛔ NON-NEGOTIABLE RULES

These rules ALWAYS apply and may NEVER be skipped:

1. **Run ALL tests** – Before every commit, ALL tests MUST be green
2. **100% coverage for new code** – Coverage may NEVER decrease
3. **Show test output** – Present test results to the human BEFORE commit
4. **No linter disables** – NEVER use `rubocop:disable` or similar comments

### Validation Checkpoint (BEFORE every commit)

```bash
# 1. Run complete local CI
bin/ci

# Coverage for new files: 100%
# Total coverage: must not decrease

# 2. Brakeman and RuboCop analysis
# Do NOT ignore/mute warnings. Fix the problem.
# If not sensible, ask the human for permission.

# 3. Show validation output to human
```

**STOP!** If any of these points fail → Task is NOT complete. Fix the problem.

---

## Important Project Files

### ✅ Always read (for every feature):
- This file (CLAUDE.md): Workflows and best practices
- `GLOSSARY.md`: Domain-specific terms and definitions
- `docs/architecture/README.md`: System overview and architecture principles
- `docs/features/README.md`: Feature index - shows existing features

### 📋 Read only when needed:
- `docs/architecture/decisions/XXX-*.md`: Specific ADRs (only relevant ones)
- `docs/features/[feature-name]/`: Feature-specific documentation

### ⚡ Token-saving search strategy:

```
1. Start: docs/features/README.md (Feature Index)
   → Which features are similar/relevant?

2. Relevant feature: docs/features/[name]/README.md
   → Feature overview

3. If needed: Specific diagrams
   → flow.md / sequence.md / ui-mockup.md

4. For architecture questions: docs/architecture/decisions/
   → Only relevant ADRs
```

**Important:** Don't read all files! Use index files (README.md) to decide what's relevant.

---

## Code Style & Conventions

### Ruby Style

- Use Ruby 4.x features where appropriate
- Prefer `frozen_string_literal: true` magic comment in all files
- Maximum line length: 120 characters
- Use double quotes for strings consistently
- Prefer symbols over strings for hash keys
- Use trailing commas in multi-line arrays and hashes

### Naming Conventions

- Classes/Modules: `PascalCase`
- Methods/Variables: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`
- Predicates: end with `?` (e.g., `valid?`, `active?`)
- Dangerous methods: end with `!` (e.g., `save!`, `destroy!`)
- Use descriptive names – clarity over brevity

### Method Design

- Keep methods short (< 15 lines ideally)
- Single responsibility per method
- Prefer keyword arguments for methods with 3+ parameters
- Use guard clauses for early returns
- Avoid deep nesting (max 2-3 levels)

```ruby
# Good: Guard clause
def process(user)
  return unless user.active?

  # main logic
end

# Avoid: Nested conditionals
def process(user)
  if user.active?
    # deeply nested logic
  end
end
```

---

## Rails Architecture

### Directory Structure

```
app/
├── controllers/     # Thin controllers, delegate to interactions
├── models/          # ActiveRecord models, validations, scopes
├── interactions/    # Business logic using LightService
├── views/           # ERB templates
├── helpers/         # View helpers (use sparingly)
├── components/      # ViewComponent components
├── jobs/            # Background jobs (Sidekiq)
├── mailers/         # ActionMailer classes
└── javascript/      # Stimulus controllers (Import Maps)
```

### Controllers

- Keep controllers thin – max 5-7 public actions
- Use `before_action` for shared setup
- Delegate business logic to Service Objects
- Use strong parameters consistently

```ruby
class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def create
    result = Users::CreateService.call(user_params)

    if result.success?
      redirect_to result.user, notice: "User created."
    else
      @user = result.user
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
```

### Models

- Keep models focused on data concerns: validations, associations, scopes
- Extract complex queries into scopes or query objects
- Avoid callbacks for business logic – use services instead
- Use `has_many through:` over `has_and_belongs_to_many`

```ruby
class User < ApplicationRecord
  # Constants first
  ROLES = %w[admin member guest].freeze

  # Associations
  has_many :posts, dependent: :destroy
  belongs_to :organization

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: "admin") }
  scope :created_after, ->(date) { where("created_at > ?", date) }

  # Instance methods
  def admin?
    role == "admin"
  end
end
```

### Interactions (LightService)

Place in `app/interactions/`. Use LightService for business logic with multiple steps.

```ruby
# app/interactions/users/create_user.rb
module Users
  class CreateUser
    extend LightService::Organizer

    def self.call(params)
      with(params: params).reduce(
        ValidateParams,
        CreateRecord,
        SendWelcomeEmail
      )
    end
  end

  class ValidateParams
    extend LightService::Action

    expects :params
    promises :validated_params

    executed do |context|
      # validation logic
      context.validated_params = context.params.slice(:name, :email)
    end
  end

  class CreateRecord
    extend LightService::Action

    expects :validated_params
    promises :user

    executed do |context|
      user = User.new(context.validated_params)

      if user.save
        context.user = user
      else
        context.fail_and_return!("User creation failed", user.errors)
      end
    end
  end

  class SendWelcomeEmail
    extend LightService::Action

    expects :user

    executed do |context|
      UserMailer.welcome(context.user).deliver_later
    end
  end
end
```

### Controller Integration

```ruby
class UsersController < ApplicationController
  def create
    result = Users::CreateUser.call(user_params)

    if result.success?
      redirect_to result.user, notice: "User created."
    else
      @user = result.user || User.new
      flash.now[:alert] = result.message
      render :new, status: :unprocessable_entity
    end
  end
end
```

### Concerns

- Use for shared behavior across multiple models/controllers
- Keep concerns focused and small
- Prefer composition over deep concern hierarchies

### ViewComponents

Place in `app/components/`. Use for reusable UI elements.

```ruby
# app/components/button_component.rb
class ButtonComponent < ViewComponent::Base
  def initialize(label:, variant: :primary, **options)
    @label = label
    @variant = variant
    @options = options
  end

  def css_classes
    base = "btn"
    variant_class = "btn--#{@variant}"
    "#{base} #{variant_class}"
  end
end
```

```erb
<%# app/components/button_component.html.erb %>
<button class="<%= css_classes %>" <%= tag.attributes(@options) %>>
  <%= @label %>
</button>
```

Usage in views:
```erb
<%= render ButtonComponent.new(label: "Save", variant: :primary) %>
```

---

## Views & Frontend

### ERB Templates

- Keep logic minimal – use helpers or presenters
- Use partials for reusable components
- Prefer `collection` rendering for lists

```erb
<%# Good: Collection rendering %>
<%= render partial: "post", collection: @posts %>

<%# Avoid: Manual iteration with logic %>
<% @posts.each do |post| %>
  <% if post.published? %>
    <%= render "post", post: post %>
  <% end %>
<% end %>
```

### Hotwire / Turbo

- Use Turbo Frames for partial page updates
- Use Turbo Streams for real-time updates
- Stimulus for JavaScript behavior
- Keep Stimulus controllers small and focused

```erb
<%# Turbo Frame example %>
<%= turbo_frame_tag "user_#{user.id}" do %>
  <%= render "user", user: user %>
<% end %>
```

```javascript
// Stimulus controller
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  greet() {
    this.outputTarget.textContent = "Hello!"
  }
}
```

---

## Workflow for New Features

### Overview of Phases:
1. Understand requirements
2. Create Gherkin scenario
3. Visualization & Design (for larger features)
4. Store documentation ⚠️ Important!
5. Implementation
6. Write tests (100% coverage!)
7. Code quality & linting (fix only new problems!)
8. Update feature index
9. Create commit (with human review before push)

### 1. Understand Requirements

**IMPORTANT:** Always ask the human for significant content changes!

When developing a new feature:
1. Ask clarifying questions to fully understand the feature
2. Check the glossary (`docs/GLOSSARY.md`)
3. Distinguish: Small things vs. content changes

**✅ Can decide independently (small things):**
- Optimize button text
- Reword error messages
- UI layout details (spacing, colors within design system)
- Variable/function names
- Code structure/refactoring (without behavior change)

**❌ ALWAYS ask the human (content changes):**
- Add new features
- Change or remove existing features
- Change business logic
- Change data model
- Change API interfaces
- Change validation rules
- Change authorization/permission logic
- Change what data is stored/processed
- Change user flow

### 2. Create Gherkin Scenario

**IMPORTANT:** Always write Gherkin scenarios in English!

After understanding the feature:
1. Write a Gherkin scenario as understanding check
2. Present it to the human for review
3. Wait for feedback
4. Make your own suggestions (edge cases, error handling)

```gherkin
Feature: [Feature Name]
  As a [Role/User]
  I want to [Goal]
  So that [Benefit/Reason]

  Scenario: [Scenario Description]
    Given [Initial State]
    And [Additional Precondition]
    When [Action]
    Then [Expected Result]
    And [Additional Expected Result]
```

### 3. Visualization & Design (for larger features)

After the Gherkin phase, create visualizations:
- Mermaid diagrams: For flows, architectures, sequences
- ASCII-art mockups: For UI features
- Data models: For database structures
- State machines: For state transitions

Use templates from `docs/templates/`.

### 4. Store Documentation

**IMPORTANT:** Document during work, not after!

```bash
mkdir -p docs/features/[feature-name]
```

Store:
- Gherkin scenarios: `docs/features/[feature-name]/feature.gherkin`
- Mermaid diagrams: `docs/features/[feature-name]/flow.md`
- ASCII mockups: `docs/features/[feature-name]/ui-mockup.md`
- Feature documentation: `docs/features/[feature-name]/README.md`

### 5-9. Implementation through Commit

See detailed sections below.

---

## Testing

### Ruby Tests (RSpec)

```bash
bundle exec rspec
```

### JavaScript Tests (Jest)

```bash
npm test
```

### File Structure

```
spec/
├── models/          # Model specs
├── requests/        # Request/integration specs (prefer over controller specs)
├── interactions/    # LightService interaction specs
├── components/      # ViewComponent specs
├── system/          # System/feature specs with Capybara
├── support/         # Shared helpers, configurations
└── factories/       # FactoryBot factories
```

### General Guidelines

- Use `describe` for classes/methods, `context` for states/conditions
- Use `let` for lazy-loaded test data
- Use `let!` only when eager loading is necessary
- Prefer `build_stubbed` over `create` when persistence isn't needed
- One expectation per example (when reasonable)

```ruby
RSpec.describe User, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe "#admin?" do
    context "when user has admin role" do
      let(:user) { build(:user, role: "admin") }

      it "returns true" do
        expect(user.admin?).to be true
      end
    end

    context "when user has member role" do
      let(:user) { build(:user, role: "member") }

      it "returns false" do
        expect(user.admin?).to be false
      end
    end
  end
end
```

### Request Specs

Prefer request specs over controller specs:

```ruby
RSpec.describe "Users", type: :request do
  describe "POST /users" do
    let(:valid_params) { { user: { name: "Test", email: "test@example.com" } } }

    context "with valid parameters" do
      it "creates a new user" do
        expect {
          post users_path, params: valid_params
        }.to change(User, :count).by(1)
      end

      it "redirects to the user" do
        post users_path, params: valid_params
        expect(response).to redirect_to(User.last)
      end
    end
  end
end
```

### Factories (FactoryBot)

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    role { "member" }

    trait :admin do
      role { "admin" }
    end

    trait :with_posts do
      after(:create) do |user|
        create_list(:post, 3, user: user)
      end
    end
  end
end
```

---

## Database

### Migrations

- Use descriptive migration names
- Add indexes for foreign keys and frequently queried columns
- Use `null: false` constraints where appropriate
- Add database-level constraints, not just model validations
- Always include `down`/`rollback` method
- Document rollback strategy in feature docs

```ruby
class CreateUsers < ActiveRecord::Migration[8.1]
  def up
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false, default: "member"
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
  end

  def down
    drop_table :users
  end
end
```

### Query Optimization

- Use `includes` to prevent N+1 queries
- Use `select` to limit loaded columns when appropriate
- Use `find_each` for batch processing large datasets

```ruby
# Good: Eager loading
User.includes(:posts).where(active: true)

# Good: Batch processing
User.find_each(batch_size: 1000) do |user|
  # process user
end
```

---

## Dependencies & Gems

**RULE:** Minimize new dependencies!

When a new dependency seems necessary:

1. **Check alternatives WITHOUT dependency:**
   - Can it be solved with stdlib?
   - Is the functionality already in existing gems?

2. **Research before proposing:**
   - Check Ruby Toolbox (https://www.ruby-toolbox.com/)
   - Gem freshness: Last update, active maintenance?
   - Popularity: Downloads, GitHub Stars
   - Security: Known vulnerabilities?
   - Dependencies: Does it pull many other dependencies?

3. **Human must approve:**

```
Agent: "For the PDF export feature there are two options:

Option 1 (without gem):
- Use Ruby's built-in libraries
- More code, but no dependency
- Full control

Option 2 (with gem 'prawn'):
- Gem: prawn (v2.4.0, last update: 2 months)
- Ruby Toolbox Score: 8/10
- 5M+ downloads, actively maintained
- Pulls 3 additional dependencies
- Less code, well tested

Which option do you prefer?"
```

**NEVER without asking:**
- Run `gem install`
- Modify `Gemfile`
- Modify `package.json`

---

## Security

**CRITICAL:** Security First - no simple OWASP mistakes!

### Security Tools
- **Brakeman**: Static analysis
- **bundle audit**: Check for vulnerable gems

### Input Validation
- ❌ NEVER trust user input
- ✅ ALWAYS validate and sanitize
- ✅ Whitelist instead of blacklist

```ruby
# ❌ BAD
Report.where("user_id = #{params[:user_id]}")

# ✅ GOOD
Report.where(user_id: params[:user_id])
```

### Authorization
Clarify before implementation:
- Who may access?
- What permissions are needed?

### Security Checklist
- Input Validation (all user inputs)
- Authorization (who may do what?)
- Authentication (if relevant)
- SQL Injection prevented (parameterized queries)
- XSS prevented (output escaping)
- CSRF protection (for forms)
- Sensitive Data Exposure (logs, errors)
- File Upload Validation (type, size, content)
- Rate Limiting (for APIs)

### OWASP Top 10 Prevention
- A01: Broken Access Control → Always check authorization
- A02: Cryptographic Failures → No plaintext secrets
- A03: Injection → Parameterized queries, input validation
- A04: Insecure Design → Consider security in planning phase
- A05: Security Misconfiguration → Don't change defaults without reason
- A07: Identification & Auth Failures → Use strong auth
- A08: Software & Data Integrity → Check dependencies
- A09: Security Logging Failures → Don't ignore errors
- A10: SSRF → Validate URL inputs

---

## Code Quality & Linting

**CRITICAL:** Do NOT modify linter configurations!

### Rules
- ✅ ONLY fix problems in newly created or modified files
- ✅ ONLY fix problems that are newly introduced
- ❌ DO NOT fix existing problems in unchanged files
- ❌ NEVER modify linter configurations (`.rubocop.yml`, `.eslintrc`, etc.)

### Workflow

```bash
# 1. Run linter on changed files
rubocop path/to/modified/file.rb

# 2. Auto-fix only if safe
rubocop -a path/to/modified/file.rb

# 3. If uncertain: Ask the human
```

### NEVER use `rubocop:disable` comments

- ❌ FORBIDDEN: `# rubocop:disable Metrics/MethodLength`
- ✅ INSTEAD: Refactor code to solve the problem

```ruby
# ❌ WRONG - Hide problem
# rubocop:disable Metrics/ClassLength
class BigController < ApplicationController
  # 200 lines of code...
end
# rubocop:enable Metrics/ClassLength

# ✅ RIGHT - Solve problem through refactoring
class SmallController < ApplicationController
  include RoutingConcern
  include ImageServingConcern
  # Now only 50 lines
end
```

---

## Performance

**RULE:** Discuss performance-critical decisions with human!

### Async-First Approach
- Long-running tasks (>2 seconds): Always async
- Use Background Jobs (Sidekiq)
- User should not have to wait

### Before Implementation

```
Agent: "The report export could take 10+ seconds for large files.

Proposal: Background Job with Sidekiq
- User gets email when done
- No UI blocking
- Progress tracking possible

Is that OK?"
```

---

## CI/CD & Tooling

### Required Tools
- **RuboCop**: Code style enforcement
- **Brakeman**: Security scanning
- **RSpec**: Ruby testing
- **Jest**: JavaScript testing
- **FactoryBot**: Test data
- **SimpleCov**: Coverage reporting

### System Dependencies
- `rclone`: File syncing to deployment targets
- `libvips`: Image processing
- `PostgreSQL 17`: Database

### GitHub Actions Workflow

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Setup database
        run: bin/rails db:setup
        env:
          RAILS_ENV: test

      - name: Run CI
        run: bin/ci
```

### Deployment (Kamal)

```bash
kamal lock release -d production
kamal envify -d production
kamal accessory boot all -d production
kamal deploy -d production
```

**NEVER deploy without human approval.**

---

## Commit Guidelines

**IMPORTANT:** Human must give OK before push!

### Workflow

1. Create meaningful commit:

```bash
git add docs/features/report-export/
git add app/models/report_exporter.rb
git add spec/models/report_exporter_spec.rb

git commit -m "$(cat <<'EOF'
Add report export feature

- Implement PDF and Excel export for reports
- Add size validation (max 10MB)
- Add permission checks (Admin/Owner only)
- Include Gherkin scenarios and documentation
- 100% test coverage achieved

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

2. Show commit details to human: `git show HEAD`

3. Wait for confirmation before push

**NEVER without asking:**
- Push to main/master
- Force push
- Create pull request

---

## Memory Management

Claude can create memory files in `.claude/memories/` to persist project-specific context:

- `decisions.md` – Architectural decisions and their rationale
- `patterns.md` – Project-specific patterns discovered during work
- `gotchas.md` – Edge cases and things to watch out for

When working on this project:
1. Check existing memories before starting complex tasks
2. Update memories when discovering important patterns or making decisions
3. Reference memories in responses when relevant

---

## Communication Guidelines

### Ask Questions
- Always ask when something is unclear
- Better one question too many than too few
- Ask specific questions, not general ones

### Make Suggestions
- Proactively suggest improvements
- Show alternatives
- Address potential problems early

### Use Domain Language
- Use terms from GLOSSARY.md
- Add new terms to the glossary
- Consistent terminology in code and documentation

---

## Notes

### No Change History in Documents
**Decision:** No change history in documents under `docs/` - or anywhere else in the code.

This means:
- ❌ No "Changelog" sections in Markdown files
- ❌ No "History" or "Revision" tables in documents
- ❌ No change dates at file end
- ✅ Git history is the only source for change history
