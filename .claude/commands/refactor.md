# Refactor Command

Refactor code while preserving behavior and improving quality.

## Usage

```
/refactor [file_or_directory] [--focus=area]
```

Focus areas: `readability`, `performance`, `testability`, `security`, `rails-conventions`

## Refactoring Principles

### Golden Rules
1. **Never change behavior** - Refactoring improves structure, not functionality
2. **Tests must pass** - Run tests before and after every change
3. **Small steps** - Make incremental changes, commit frequently
4. **No rubocop:disable** - Fix the problem, don't hide it

### Before Starting
1. Ensure tests exist and pass
2. Understand the current behavior
3. Identify the smell or problem
4. Plan the refactoring approach

## Common Refactorings

### Extract Method
```ruby
# Before
def process_order(order)
  # 50 lines of code
end

# After
def process_order(order)
  validate_order(order)
  calculate_totals(order)
  apply_discounts(order)
  finalize_order(order)
end
```

### Extract Service Object
```ruby
# Before: Fat controller
def create
  @user = User.new(user_params)
  if @user.save
    UserMailer.welcome(@user).deliver_later
    Analytics.track("user_created", @user.id)
    redirect_to @user
  else
    render :new
  end
end

# After: Thin controller + Service
def create
  result = Users::CreateService.call(user_params)
  if result.success?
    redirect_to result.user
  else
    @user = result.user
    render :new
  end
end
```

### Replace Conditional with Polymorphism
```ruby
# Before
def price
  case type
  when "standard" then base_price
  when "premium" then base_price * 1.5
  when "enterprise" then base_price * 3
  end
end

# After: Use STI or Strategy pattern
class StandardPlan < Plan
  def price = base_price
end

class PremiumPlan < Plan
  def price = base_price * 1.5
end
```

### Extract Concern
```ruby
# Before: Repeated code in models
class User < ApplicationRecord
  def full_name = "#{first_name} #{last_name}"
end

class Employee < ApplicationRecord
  def full_name = "#{first_name} #{last_name}"
end

# After: Shared concern
module HasFullName
  extend ActiveSupport::Concern

  def full_name = "#{first_name} #{last_name}"
end
```

## Workflow

1. **Identify** - What needs refactoring and why?
2. **Test** - Ensure tests pass: `bin/ci`
3. **Refactor** - Make one change at a time
4. **Test** - Ensure tests still pass
5. **Review** - Check with `/review`
6. **Commit** - Small, focused commits

## Output Format

```
## Refactoring Plan

**Target:** path/to/file.rb
**Focus:** [area]
**Risk Level:** Low/Medium/High

### Changes Proposed

1. [Change description]
   - Before: [brief description]
   - After: [brief description]
   - Risk: [potential issues]

### Dependencies
- Files that may be affected
- Tests that need updating

### Verification Steps
1. Run specific tests
2. Manual verification needed?
```

## Safety Checks

Before applying changes:
- [ ] All tests pass
- [ ] No behavior change intended
- [ ] Changes are incremental
- [ ] Human approved the plan
