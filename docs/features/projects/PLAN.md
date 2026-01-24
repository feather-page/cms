# Developer Project Portfolio - Implementation Plan

## Overview

Feature to showcase development projects on static sites. Projects get their own detail pages (like posts) and are listed on pages with `page_type_projects?` (like books).

---

## 1. Gherkin Features (English)

**File:** `docs/features/projects/feature.gherkin`

```gherkin
Feature: Developer Project Portfolio
  As a developer
  I want to showcase my projects on my portfolio website
  So that potential employers and clients can see my experience

  Background:
    Given I am logged in as a site owner
    And I have a site "My Portfolio"

  # ─────────────────────────────────────────────────────────────
  # CRUD Operations (Admin)
  # ─────────────────────────────────────────────────────────────

  Scenario: Creating a new project
    When I navigate to the projects section
    And I click "New Project"
    And I fill in the project form with:
      | Title             | Backend Refactoring gutefrage.net     |
      | Company           | gutefrage.net                         |
      | Period            | March 2019 - August 2020              |
      | Started at        | 2019-03-01                            |
      | Ended at          | 2020-08-31                            |
      | Status            | Completed                             |
      | Role              | Senior Backend Developer              |
      | Short description | Complete API overhaul with Rails 6... |
      | Project type      | Professional                          |
    And I add a header image
    And I write detailed content using the editor
    And I add links:
      | Label   | URL                          |
      | Website | https://www.gutefrage.net    |
    And I click "Save"
    Then I should see "Project created successfully"
    And the project should appear in the projects list
    And the project slug should be "backend-refactoring-gutefrage-net"

  Scenario: Editing an existing project
    Given I have a project "Old API Client"
    When I edit the project
    And I change the title to "Modern API Client"
    And I change the status to "Abandoned"
    And I click "Save"
    Then I should see "Project updated successfully"
    And the project should show "Modern API Client" in the list
    And the project slug should be updated to "modern-api-client"

  Scenario: Deleting a project
    Given I have a project "Test Project"
    When I delete the project "Test Project"
    And I confirm the deletion
    Then the project should no longer appear in the list

  Scenario: Creating an ongoing project
    When I create a new project with:
      | Title      | Side Project Tracker |
      | Started at | 2024-01-15           |
      | Status     | Ongoing              |
    And I leave "Ended at" empty
    Then the project period should display as "January 2024 - ongoing"

  # ─────────────────────────────────────────────────────────────
  # Project Types and Statuses
  # ─────────────────────────────────────────────────────────────

  Scenario: Creating projects with different types
    When I create projects with the following types:
      | Title              | Type         | Company        |
      | Crypto Tracker     | Private      |                |
      | Yigg Optimization  | Professional | yigg.de        |
      | WP Plugin          | Open Source  |                |
      | Startup MVP        | Freelance    | TechCorp GmbH  |
    Then all projects should appear in the list
    And each project should display its type correctly

  Scenario: Project status transitions
    Given I have an ongoing project "Active Development"
    When I edit the project
    And I change the status from "Ongoing" to "Paused"
    Then the project should show status "Paused"
    When I edit the project again
    And I change the status to "Abandoned"
    Then the project should show status "Abandoned"

  # ─────────────────────────────────────────────────────────────
  # Projects List Page (Frontend)
  # ─────────────────────────────────────────────────────────────

  Scenario: Projects page displays all projects
    Given I have the following projects:
      | Title           | Started at | Status    |
      | Latest Project  | 2024-06-01 | Ongoing   |
      | Middle Project  | 2023-01-15 | Completed |
      | Old Project     | 2020-03-01 | Completed |
    And I have a page "Portfolio" with page type "projects"
    When a visitor views the "Portfolio" page
    Then they should see projects in reverse chronological order:
      | 1. Latest Project  |
      | 2. Middle Project  |
      | 3. Old Project     |

  Scenario: Empty projects page
    Given I have no projects
    And I have a page "Portfolio" with page type "projects"
    When a visitor views the "Portfolio" page
    Then they should see a message "No projects yet"

  # ─────────────────────────────────────────────────────────────
  # Project Detail Pages (Frontend)
  # ─────────────────────────────────────────────────────────────

  Scenario: Project detail page with full content
    Given I have a project "gutefrage Backend" with:
      | Company           | gutefrage.net              |
      | Period            | 2019 - 2020                |
      | Role              | Senior Developer           |
      | Status            | Completed                  |
      | Short description | API modernization project  |
      | Content           | Detailed EditorJS content  |
      | Links             | Website: gutefrage.net     |
    When a visitor navigates to "/projects/gutefrage-backend/"
    Then they should see the project title "gutefrage Backend"
    And they should see the company "gutefrage.net"
    And they should see the role "Senior Developer"
    And they should see the period "2019 - 2020"
    And they should see the status badge "Completed"
    And they should see the detailed content
    And they should see the project links

  Scenario: Project detail page SEO
    Given I have a project "My Awesome Project" with:
      | Short description | A great project description |
      | Header image      | project-screenshot.jpg      |
    When a visitor views the project detail page
    Then the page title should contain "My Awesome Project"
    And the meta description should contain "A great project description"
    And the og:image should be set to the header image

  # ─────────────────────────────────────────────────────────────
  # Static Site Generation
  # ─────────────────────────────────────────────────────────────

  Scenario: Static site includes project pages
    Given I have projects:
      | Title     | Slug      |
      | Project A | project-a |
      | Project B | project-b |
    When the static site is generated
    Then the following files should exist:
      | projects/project-a/index.html |
      | projects/project-b/index.html |
    And the files should contain valid HTML without external resources

  Scenario: Projects list on static page
    Given I have a page "Work" with page type "projects"
    And I have 3 projects
    When the static site is generated
    Then the "work/index.html" file should contain the projects list
    And each project card should link to its detail page
```

---

## 2. UI Mockups

### Admin: Projects Index

```
┌─────────────────────────────────────────────────────────────────┐
│  🏠 My Portfolio  ▾                                    [User ▾] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📁 Projects                              [+ New Project]       │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 🚀 Backend Refactoring gutefrage.net                    │   │
│  │ gutefrage.net · March 2019 - August 2020                │   │
│  │ ┌──────────┐                                            │   │
│  │ │Completed │  Senior Backend Developer                  │   │
│  │ └──────────┘                                            │   │
│  │                                    [Edit]  [Delete]     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 💡 Side Project Tracker                                 │   │
│  │ January 2024 - ongoing                                  │   │
│  │ ┌─────────┐                                             │   │
│  │ │ Ongoing │  Private                                    │   │
│  │ └─────────┘                                             │   │
│  │                                    [Edit]  [Delete]     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 🔧 Yigg.de Performance Optimization                     │   │
│  │ yigg.de · 2018 - 2019                                   │   │
│  │ ┌───────────┐                                           │   │
│  │ │ Abandoned │  Lead Developer                           │   │
│  │ └───────────┘                                           │   │
│  │                                    [Edit]  [Delete]     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ◀ 1 2 3 ▶                                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Admin: Project Form (New/Edit)

```
┌─────────────────────────────────────────────────────────────────┐
│  🏠 My Portfolio  ▾                                    [User ▾] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📁 New Project                                                 │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Header Image                                           │   │
│  │  ┌─────────────────┐                                    │   │
│  │  │                 │  [Upload Image] [Search Unsplash]  │   │
│  │  │   📷 Drop or   │                                    │   │
│  │  │   click here    │  Or use emoji: [🚀]               │   │
│  │  │                 │                                    │   │
│  │  └─────────────────┘                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Title *                                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Backend Refactoring gutefrage.net                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Slug *                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ backend-refactoring-gutefrage-net           ✓ Available │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Company                           Role                         │
│  ┌──────────────────────┐         ┌──────────────────────┐     │
│  │ gutefrage.net        │         │ Senior Backend Dev   │     │
│  └──────────────────────┘         └──────────────────────┘     │
│                                                                 │
│  Period (Display)                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ March 2019 - August 2020                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ℹ️ Optional. If empty, dates below are used for display.      │
│                                                                 │
│  Started at *                      Ended at                     │
│  ┌──────────────────────┐         ┌──────────────────────┐     │
│  │ 📅 2019-03-01        │         │ 📅 2020-08-31        │     │
│  └──────────────────────┘         └──────────────────────┘     │
│                                   ℹ️ Leave empty if ongoing     │
│                                                                 │
│  Status *                          Project Type                 │
│  ┌──────────────────────┐         ┌──────────────────────┐     │
│  │ Completed          ▾ │         │ Professional       ▾ │     │
│  └──────────────────────┘         └──────────────────────┘     │
│                                                                 │
│  Short Description *                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Complete overhaul of the REST API, migration from       │   │
│  │ Rails 4 to Rails 6, performance improvements...         │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ℹ️ 2-3 sentences for the overview. Shown on project cards.    │
│                                                                 │
│  Detailed Description                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ═══════════════════════════════════════════════════════ │   │
│  │                    [EditorJS Editor]                    │   │
│  │                                                         │   │
│  │  ## The Challenge                                       │   │
│  │                                                         │   │
│  │  The existing API was built on Rails 4 and had         │   │
│  │  significant performance issues...                      │   │
│  │                                                         │   │
│  │  ## Solution                                            │   │
│  │                                                         │   │
│  │  ```ruby                                                │   │
│  │  class ApiController < ApplicationController            │   │
│  │    # Code example                                       │   │
│  │  end                                                    │   │
│  │  ```                                                    │   │
│  │                                                         │   │
│  │  [+ Add Block]                                          │   │
│  │ ═══════════════════════════════════════════════════════ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Links                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Label              URL                                 │   │
│  │  ┌────────────┐    ┌────────────────────────┐  [✕]     │   │
│  │  │ Website    │    │ https://gutefrage.net  │          │   │
│  │  └────────────┘    └────────────────────────┘          │   │
│  │  ┌────────────┐    ┌────────────────────────┐  [✕]     │   │
│  │  │ Case Study │    │ https://example.com/cs │          │   │
│  │  └────────────┘    └────────────────────────┘          │   │
│  │                                                         │   │
│  │  [+ Add Link]                                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────┐  ┌────────────────┐                          │
│  │    Save      │  │    Cancel      │                          │
│  └──────────────┘  └────────────────┘                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Frontend: Projects List Page (Static Site)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  🏠 Home    📝 Blog    📁 Projects    📧 Contact                │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                         My Projects                             │
│                                                                 │
│  Here's a selection of projects I've worked on over the years. │
│                                                                 │
│  ═══════════════════════════════════════════════════════════   │
│                                                                 │
│  2024                                                           │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  ┌──────────────────────────────┐ ┌──────────────────────────┐ │
│  │ ┌──────────────────────────┐ │ │ ┌──────────────────────┐ │ │
│  │ │                          │ │ │ │                      │ │ │
│  │ │     [Header Image]       │ │ │ │    [Header Image]    │ │ │
│  │ │                          │ │ │ │                      │ │ │
│  │ └──────────────────────────┘ │ │ └──────────────────────┘ │ │
│  │                              │ │                          │ │
│  │ 🚀 Side Project Tracker     │ │ 💼 Startup MVP           │ │
│  │ ┌────────┐                   │ │ TechCorp GmbH            │ │
│  │ │Ongoing │ Private           │ │ ┌──────────┐             │ │
│  │ └────────┘                   │ │ │Completed │ Freelance   │ │
│  │                              │ │ └──────────┘             │ │
│  │ Personal productivity tool   │ │ Built MVP for early-     │ │
│  │ for tracking side projects   │ │ stage fintech startup... │ │
│  │ and learning goals...        │ │                          │ │
│  │                              │ │                          │ │
│  └──────────────────────────────┘ └──────────────────────────┘ │
│                                                                 │
│  2019 - 2020                                                    │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  ┌──────────────────────────────┐ ┌──────────────────────────┐ │
│  │ ┌──────────────────────────┐ │ │ ┌──────────────────────┐ │ │
│  │ │                          │ │ │ │                      │ │ │
│  │ │     [Header Image]       │ │ │ │    [Header Image]    │ │ │
│  │ │                          │ │ │ │                      │ │ │
│  │ └──────────────────────────┘ │ │ └──────────────────────┘ │ │
│  │                              │ │                          │ │
│  │ 🔧 Backend Refactoring      │ │ 📊 Yigg.de Analytics     │ │
│  │ gutefrage.net               │ │ yigg.de                  │ │
│  │ ┌──────────┐                 │ │ ┌───────────┐            │ │
│  │ │Completed │ Professional    │ │ │ Abandoned │ Prof.      │ │
│  │ └──────────┘                 │ │ └───────────┘            │ │
│  │                              │ │                          │ │
│  │ Complete API overhaul,       │ │ Real-time analytics      │ │
│  │ Rails 4 to 6 migration...    │ │ dashboard project...     │ │
│  │                              │ │                          │ │
│  └──────────────────────────────┘ └──────────────────────────┘ │
│                                                                 │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│  © 2024 Max Mustermann                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Frontend: Project Detail Page (Static Site)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  🏠 Home    📝 Blog    📁 Projects    📧 Contact                │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │                    [Header Image]                       │   │
│  │                    Screenshot/Logo                      │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  🚀 Backend Refactoring gutefrage.net                          │
│                                                                 │
│  ┌──────────┐  gutefrage.net · March 2019 - August 2020        │
│  │Completed │  Senior Backend Developer                        │
│  └──────────┘                                                   │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Complete overhaul of the REST API, migration from Rails 4     │
│  to Rails 6, and significant performance improvements that     │
│  reduced response times by 60%.                                │
│                                                                 │
│  ═══════════════════════════════════════════════════════════   │
│                                                                 │
│  ## The Challenge                                               │
│                                                                 │
│  The existing API was built on Rails 4 and had significant     │
│  performance issues. With millions of daily requests, even     │
│  small improvements would have a massive impact.               │
│                                                                 │
│  Key problems:                                                  │
│  • N+1 queries throughout the codebase                         │
│  • No caching strategy                                         │
│  • Outdated authentication system                              │
│                                                                 │
│  ## Solution                                                    │
│                                                                 │
│  We approached this in three phases:                           │
│                                                                 │
│  1. **Audit & Planning** - Identified bottlenecks using        │
│     NewRelic and created a prioritized roadmap                 │
│                                                                 │
│  2. **Incremental Migration** - Upgraded Rails version by      │
│     version while maintaining backwards compatibility          │
│                                                                 │
│  3. **Performance Optimization** - Implemented Redis caching,  │
│     optimized database queries, added connection pooling       │
│                                                                 │
│  ```ruby                                                        │
│  # Example: Before                                              │
│  def index                                                      │
│    @posts = Post.all                                           │
│    @posts.each { |p| p.author.name } # N+1!                    │
│  end                                                            │
│                                                                 │
│  # After                                                        │
│  def index                                                      │
│    @posts = Post.includes(:author).all                         │
│  end                                                            │
│  ```                                                            │
│                                                                 │
│  ## Results                                                     │
│                                                                 │
│  • 60% reduction in average response time                      │
│  • 40% reduction in database load                              │
│  • Zero downtime during migration                              │
│                                                                 │
│  ═══════════════════════════════════════════════════════════   │
│                                                                 │
│  Links                                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🔗 Website     → gutefrage.net                         │   │
│  │  📄 Case Study  → example.com/case-study                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  ← Back to Projects                                             │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│  © 2024 Max Mustermann                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Database Migration

**File:** `db/migrate/YYYYMMDDHHMMSS_create_projects.rb`

```ruby
create_table :projects, id: :uuid do |t|
  t.string :public_id, limit: 21, null: false
  t.references :site, null: false, foreign_key: true, type: :uuid
  t.references :header_image, foreign_key: { to_table: :images }, type: :uuid

  t.string :title, null: false
  t.string :slug, null: false
  t.string :company
  t.string :period                      # Display: "März 2019 - August 2020"
  t.date :started_at, null: false       # For sorting
  t.date :ended_at                      # nil = ongoing
  t.integer :status, default: 0         # enum
  t.string :role
  t.text :short_description, null: false
  t.json :content                       # EditorJS
  t.integer :project_type               # enum
  t.json :links                         # [{label, url}]
  t.string :emoji

  t.index :public_id, unique: true
  t.index [:slug, :site_id], unique: true
  t.index :started_at

  t.timestamps
end
```

---

## 4. Model

**File:** `app/models/project.rb`

- `include PublicIdable`, `include Editable`
- `belongs_to :site`, `belongs_to :header_image, optional: true`
- Enums: `status` (ongoing/completed/paused/abandoned), `project_type` (professional/private/open_source/freelance)
- Validations: title, slug, short_description, started_at
- Scopes: `ordered` (started_at desc)

**Update:** `app/models/page.rb:4` → `projects: 2`
**Update:** `app/models/site.rb` → `has_many :projects`

---

## 5. Controller, Policy, Routes

- `app/controllers/projects_controller.rb` - Standard CRUD
- `app/policies/project_policy.rb` - Site users can CRUD
- `config/routes.rb` - `resources :projects`

---

## 6. ViewComponents

- `app/components/form/links_field_component.rb` - Manage link array
- `app/components/static_site/projects_list_component.rb` - Grid list
- `app/components/static_site/project_card_component.rb` - Card

---

## 7. Static Site Generation

**Update:** `app/jobs/static_site/export_job.rb` - Add `export_projects`
**Update:** `app/views/static_site/page.html.erb` - Add projects condition
**New:** `app/views/static_site/project.html.erb` - Detail template

---

## 8. Implementation Sequence

1. **Gherkin features** - Write `docs/features/projects/feature.gherkin`
2. Migration - Create projects table
3. Model - Project with validations
4. Update Page + Site models
5. Policy + Routes
6. Factory + Model specs
7. Controller + Admin views
8. Request specs
9. ViewComponents (form + static site)
10. Static site generation
11. Component specs
12. Locales (EN + DE)
13. Documentation

---

## Verification

```bash
bin/ci  # All tests green, 100% coverage for new code
```

Manual: Create projects, create page with type "projects", publish, verify static output.
