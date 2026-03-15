# Serial Deployment Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent concurrent deployments from corrupting each other by serializing ExportJob execution per DeploymentTarget.

**Architecture:** Add a `deploying` boolean with optimistic locking to `DeploymentTarget`. ExportJob acquires the lock before work, retries if locked, and releases in `ensure`. Rclone sync is inlined into ExportJob so the lock covers the full pipeline.

**Tech Stack:** Rails 8, SQLite3 (multi-database), Solid Queue, Active Record optimistic locking

**Spec:** `docs/superpowers/specs/2026-03-15-serial-deployment-design.md`

---

## Chunk 1: Database & Model

### Task 1: Migration — add deploying flag and lock_version

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_deploying_to_deployment_targets.rb`

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration AddDeployingToDeploymentTargets deploying:boolean lock_version:integer
```

- [ ] **Step 2: Edit the migration to set defaults and null constraints**

The generated migration needs `default` and `null: false` on both columns:

```ruby
class AddDeployingToDeploymentTargets < ActiveRecord::Migration[8.0]
  def change
    add_column :deployment_targets, :deploying, :boolean, default: false, null: false
    add_column :deployment_targets, :lock_version, :integer, default: 0, null: false
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: Schema updated, no errors.

- [ ] **Step 4: Verify schema**

Run: `bin/rails runner "puts DeploymentTarget.column_names.sort.join(', ')"`
Expected: Output includes `deploying` and `lock_version`.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_add_deploying_to_deployment_targets.rb db/schema.rb
git commit -m "Add deploying flag and lock_version to deployment_targets"
```

---

### Task 2: DeploymentTarget — locking methods + tests

**Files:**
- Modify: `app/models/deployment_target.rb`
- Create: `spec/models/deployment_target_spec.rb`

- [ ] **Step 1: Write failing tests for acquire_deploy_lock! and release_deploy_lock!**

Create `spec/models/deployment_target_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe DeploymentTarget do
  let(:target) { create(:deployment_target, :staging) }

  describe "#acquire_deploy_lock!" do
    it "returns true and sets deploying to true when not locked" do
      expect(target.acquire_deploy_lock!).to be true
      expect(target.reload.deploying?).to be true
    end

    it "returns false when already locked" do
      target.update!(deploying: true)

      expect(target.acquire_deploy_lock!).to be false
    end

    it "returns false on concurrent lock attempt (StaleObjectError)" do
      # Simulate: another thread acquired the lock between reload and update
      allow(target).to receive(:update!).and_raise(ActiveRecord::StaleObjectError.new(target))

      expect(target.acquire_deploy_lock!).to be false
    end
  end

  describe "#release_deploy_lock!" do
    it "sets deploying to false and resets lock_version" do
      target.update!(deploying: true)

      target.release_deploy_lock!

      target.reload
      expect(target.deploying?).to be false
      expect(target.lock_version).to eq(0)
    end

    it "succeeds even with stale in-memory state" do
      stale_target = DeploymentTarget.find(target.id)
      target.update!(deploying: true, lock_version: 5)

      # stale_target has old lock_version — update_columns bypasses optimistic locking
      stale_target.release_deploy_lock!

      target.reload
      expect(target.deploying?).to be false
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/deployment_target_spec.rb --no-color`
Expected: FAIL — `NoMethodError: undefined method 'acquire_deploy_lock!'`

- [ ] **Step 3: Implement the locking methods**

Add to `app/models/deployment_target.rb` after the `deploy` method:

```ruby
def acquire_deploy_lock!
  reload
  return false if deploying?

  update!(deploying: true)
  true
rescue ActiveRecord::StaleObjectError
  false
end

def release_deploy_lock!
  # NOTE: update_columns still includes lock_version in WHERE clause,
  # so it fails on stale objects. update_all bypasses this.
  self.class.where(id: id).update_all(deploying: false, lock_version: 0)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/deployment_target_spec.rb --no-color`
Expected: 5 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/models/deployment_target.rb spec/models/deployment_target_spec.rb
git commit -m "Add deploy lock methods to DeploymentTarget with tests"
```

---

## Chunk 2: ExportJob Refactor

### Task 3: ExportJob — add locking, inline rclone sync

**Files:**
- Modify: `app/jobs/static_site/export_job.rb`
- Modify: `spec/jobs/static_site/export_job_spec.rb`

- [ ] **Step 1: Write failing tests for locking behavior**

Replace the entire `spec/jobs/static_site/export_job_spec.rb` with the following. Key changes: stubs switch from `Rclone::DeployJob` to `Rclone::Deployer`/`Noticer`, a `perform` helper centralizes DI kwargs, and a new `"deploy locking"` context covers lock acquire/retry/release:

```ruby
require "rails_helper"

RSpec.describe StaticSite::ExportJob do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }
  let(:deployer) { class_spy(Rclone::Deployer) }
  let(:noticer) { instance_spy(Noticer) }
  let(:noticer_class) { class_spy(Noticer, new: noticer) }

  before do
    allow(StaticSite::PrecompressJob).to receive(:perform_now)
  end

  after do
    FileUtils.rm_rf(deployment_target.build_path)
  end

  def perform
    described_class.perform_now(deployment_target, deployer:, noticer: noticer_class)
  end

  describe "#perform" do
    it "creates the output directory" do
      perform

      expect(Dir.exist?(deployment_target.source_dir)).to be true
    end

    it "exports the home page" do
      perform

      index_path = File.join(deployment_target.source_dir, "index.html")
      expect(File.exist?(index_path)).to be true
      expect(File.read(index_path)).to include(ERB::Util.html_escape(site.title))
    end

    context "with pagination" do
      it "paginates posts across multiple pages" do
        create_list(:post, 26, site:, publish_at: 1.day.ago)

        perform

        page1_path = File.join(deployment_target.source_dir, "index.html")
        page2_path = File.join(deployment_target.source_dir, "page", "2", "index.html")
        expect(File.exist?(page1_path)).to be true
        expect(File.exist?(page2_path)).to be true
      end

      it "does not create page/2 when posts fit on one page" do
        create_list(:post, 3, site:, publish_at: 1.day.ago)

        perform

        page2_path = File.join(deployment_target.source_dir, "page", "2", "index.html")
        expect(File.exist?(page2_path)).to be false
      end
    end

    it "exports posts" do
      post = create(:post, site:, title: "Test Post", slug: nil, publish_at: 1.day.ago)

      perform

      post_path = File.join(deployment_target.source_dir, "posts", post.public_id.downcase, "index.html")
      expect(File.exist?(post_path)).to be true
      expect(File.read(post_path)).to include("Test Post")
    end

    it "exports posts with custom slug" do
      create(:post, site:, title: "Custom Slug Post", slug: "/my-custom-url", publish_at: 1.day.ago)

      perform

      post_path = File.join(deployment_target.source_dir, "my-custom-url", "index.html")
      expect(File.exist?(post_path)).to be true
      expect(File.read(post_path)).to include("Custom Slug Post")
    end

    it "exports pages" do
      create(:page, site:, title: "About Page", slug: "/about")

      perform

      page_path = File.join(deployment_target.source_dir, "about", "index.html")
      expect(File.exist?(page_path)).to be true
      expect(File.read(page_path)).to include("About Page")
    end

    it "exports the RSS feed" do
      create(:post, site:, title: "RSS Test Post", publish_at: 1.day.ago)

      perform

      feed_path = File.join(deployment_target.source_dir, "feed.xml")
      expect(File.exist?(feed_path)).to be true
      expect(File.read(feed_path)).to include("RSS Test Post")
    end

    it "exports robots.txt" do
      perform

      robots_path = File.join(deployment_target.source_dir, "robots.txt")
      expect(File.exist?(robots_path)).to be true
      expect(File.read(robots_path)).to include("User-agent: *")
    end

    it "calls precompress job" do
      perform

      expect(StaticSite::PrecompressJob).to have_received(:perform_now).with(deployment_target.source_dir)
    end

    it "deploys via rclone" do
      perform

      expect(deployer).to have_received(:deploy).with(deployment_target)
    end

    it "sends a success notification" do
      perform

      expect(noticer_class).to have_received(:new).with(site)
      expect(noticer).to have_received(:notice).with(
        "Site built. <a href='https://#{deployment_target.public_hostname}'>Preview</a>"
      )
    end

    context "with book reviews" do
      it "includes star ratings in posts" do
        book = create(:book, site:, title: "Clean Code", rating: 4)
        post = create(:post, site:, title: "Book Review", slug: nil, publish_at: 1.day.ago)
        book.update!(post:)

        perform

        post_path = File.join(deployment_target.source_dir, "posts", post.public_id.downcase, "index.html")
        content = File.read(post_path)
        expect(content).to include("Clean Code")
        expect(content).to include("\u2605\u2605\u2605\u2605\u2606")
      end
    end

    context "with navigation items" do
      it "exports navigation links in the correct order" do
        navigation = site.main_navigation

        page_c = create(:page, site:, title: "Page C", slug: "/page-c")
        page_a = create(:page, site:, title: "Page A", slug: "/page-a")
        page_b = create(:page, site:, title: "Page B", slug: "/page-b")

        navigation.add(page_c)
        nav_item_a = navigation.add(page_a)
        navigation.add(page_b)

        nav_item_a.move_up

        perform

        index_path = File.join(deployment_target.source_dir, "index.html")
        content = File.read(index_path)

        page_a_pos = content.index("Page A")
        page_c_pos = content.index("Page C")
        page_b_pos = content.index("Page B")

        expect(page_a_pos).to be < page_c_pos, "Page A should appear before Page C"
        expect(page_c_pos).to be < page_b_pos, "Page C should appear before Page B"
      end
    end
  end

  describe "deploy locking" do
    it "acquires the lock before exporting" do
      perform

      expect(deployment_target.reload.deploying?).to be false # released in ensure
    end

    it "retries when lock is already held" do
      deployment_target.update!(deploying: true)

      job = described_class.new
      allow(job).to receive(:retry_job)

      job.perform(deployment_target, deployer:, noticer: noticer_class)

      expect(job).to have_received(:retry_job).with(wait: 5.seconds)
      expect(deployer).not_to have_received(:deploy)
    end

    it "releases the lock when an error occurs during export" do
      deployment_target # ensure created before stubbing
      allow(StaticSite::PrecompressJob).to receive(:perform_now).and_raise(RuntimeError, "boom")

      expect {
        perform
      }.to raise_error(RuntimeError, "boom")

      expect(deployment_target.reload.deploying?).to be false
    end

    it "does not release the lock when it was not acquired" do
      deployment_target.update!(deploying: true)

      job = described_class.new
      allow(job).to receive(:retry_job)
      allow(deployment_target).to receive(:release_deploy_lock!)

      job.perform(deployment_target, deployer:, noticer: noticer_class)

      expect(deployment_target).not_to have_received(:release_deploy_lock!)
    end

    it "gives up after 60 retries and logs a warning" do
      deployment_target.update!(deploying: true)

      job = described_class.new
      allow(job).to receive(:executions).and_return(60)
      allow(job).to receive(:retry_job)
      allow(Rails.logger).to receive(:warn)

      job.perform(deployment_target, deployer:, noticer: noticer_class)

      expect(job).not_to have_received(:retry_job)
      expect(Rails.logger).to have_received(:warn).with(/stuck/)
      expect(deployer).not_to have_received(:deploy)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify locking tests fail**

Run: `bundle exec rspec spec/jobs/static_site/export_job_spec.rb --no-color`
Expected: New locking tests fail (ExportJob doesn't accept deployer/noticer kwargs yet, no lock logic).

- [ ] **Step 3: Update ExportJob implementation**

Replace the full content of `app/jobs/static_site/export_job.rb`:

```ruby
module StaticSite
  class ExportJob < ApplicationJob
    include OutputPaths

    THREAD_COUNT = 4
    POSTS_PER_PAGE = 25

    queue_as :default

    def perform(deployment_target, deployer: Rclone::Deployer, noticer: Noticer)
      @deployment_target = deployment_target
      @deployer = deployer
      @noticer = noticer
      @lock_acquired = false

      unless deployment_target.acquire_deploy_lock!
        if executions < 60
          return retry_job(wait: 5.seconds)
        else
          Rails.logger.warn("Deploy lock for target #{deployment_target.id} stuck — giving up after 60 retries")
          return
        end
      end

      @lock_acquired = true
      @site = deployment_target.site

      cleanup
      export_content
      precompress
      deploy_and_notify
    ensure
      deployment_target.release_deploy_lock! if @lock_acquired
    end

    private

    attr_reader :deployment_target, :site

    def cleanup
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
    end

    def export_content
      export_home
      export_posts
      export_projects
      export_pages
      export_images
      export_rss_feed
      export_robots_txt
    end

    def export_home
      posts = site.posts.published.order(publish_at: :desc).to_a
      total_pages = [(posts.length / POSTS_PER_PAGE.to_f).ceil, 1].max

      (1..total_pages).each do |page_number|
        page_posts = posts.slice((page_number - 1) * POSTS_PER_PAGE, POSTS_PER_PAGE) || []
        html = renderer.render_home(site: site, posts: page_posts, current_page: page_number, total_pages: total_pages)
        path = page_number == 1 ? "index.html" : "page/#{page_number}/index.html"
        write_file(path, html)
      end
    end

    def export_posts
      posts = site.posts.published.to_a
      ParallelProcessor.new(posts, thread_count: THREAD_COUNT).process do |post|
        thread_renderer = PageRenderer.new
        write_file(post_output_path(post), thread_renderer.render_post(site: site, post: post))
      end
    end

    def export_projects
      projects = site.projects.ordered.to_a
      ParallelProcessor.new(projects, thread_count: THREAD_COUNT).process do |project|
        thread_renderer = PageRenderer.new
        write_file(project_output_path(project), thread_renderer.render_project(site: site, project: project))
      end
    end

    def export_pages
      pages = site.pages.where.not(slug: "/").to_a
      ParallelProcessor.new(pages, thread_count: THREAD_COUNT).process do |page|
        thread_renderer = PageRenderer.new
        write_file(page_output_path(page), thread_renderer.render_page(site: site, page: page))
      end
    end

    def export_images
      images = ImageCollector.new(site).to_a
      image_variants = images.flat_map { |img| Image::Variants.keys.map { |key| [img, key] } }
      ParallelProcessor.new(image_variants, thread_count: THREAD_COUNT).process do |(image, variant_key)|
        copy_image_variant(image, variant_key)
      end
    end

    def copy_image_variant(image, variant_key)
      source_path = image.fs_path(variant: variant_key)
      return unless source_path && File.exist?(source_path)

      dest_path = File.join(output_dir, image_output_path(image, variant_key))
      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.cp(source_path, dest_path)
    end

    def export_rss_feed
      write_file("feed.xml", RssFeedRenderer.new(site: site, base_url: base_url).render)
    end

    def export_robots_txt
      write_file("robots.txt", robots_content)
    end

    def robots_content
      "User-agent: *\nAllow: /\n\nSitemap: #{base_url}sitemap.xml\n"
    end

    def precompress
      PrecompressJob.perform_now(output_dir)
    end

    def deploy_and_notify
      @deployer.deploy(deployment_target)
      @noticer.new(site).notice(
        "Site built. <a href='https://#{deployment_target.public_hostname}'>Preview</a>"
      )
    end

    def renderer
      @renderer ||= PageRenderer.new
    end

    def output_dir
      @output_dir ||= deployment_target.source_dir
    end

    def write_file(relative_path, content)
      full_path = File.join(output_dir, relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end

    def base_url
      deployment_target.provider == "internal" ? "/preview/#{deployment_target.id}/" : "https://#{deployment_target.public_hostname}/"
    end
  end
end
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `bundle exec rspec spec/jobs/static_site/export_job_spec.rb --no-color`
Expected: All examples pass (existing + new locking tests).

- [ ] **Step 5: Commit**

```bash
git add app/jobs/static_site/export_job.rb spec/jobs/static_site/export_job_spec.rb
git commit -m "Add deploy locking to ExportJob, inline rclone sync"
```

---

## Chunk 3: Cleanup

### Task 4: Delete Rclone::DeployJob

**Files:**
- Delete: `app/jobs/rclone/deploy_job.rb`
- Delete: `spec/jobs/rclone/deploy_job_spec.rb`

- [ ] **Step 1: Delete the files**

```bash
rm app/jobs/rclone/deploy_job.rb spec/jobs/rclone/deploy_job_spec.rb
```

- [ ] **Step 2: Search for remaining references**

Run: `grep -r "Rclone::DeployJob\|rclone/deploy_job" app/ spec/ config/ --include="*.rb" -l`
Expected: No results (ExportJob no longer references it after Task 3).

- [ ] **Step 3: Run full test suite**

Run: `bundle exec rspec --no-color`
Expected: All tests pass, no references to deleted job.

- [ ] **Step 4: Commit**

```bash
git rm app/jobs/rclone/deploy_job.rb spec/jobs/rclone/deploy_job_spec.rb
git commit -m "Remove unused Rclone::DeployJob (inlined into ExportJob)"
```

---

### Task 5: Final verification

- [ ] **Step 1: Run full test suite**

Run: `bundle exec rspec --no-color`
Expected: All tests pass, coverage >= 85%.

- [ ] **Step 2: Verify deployment still works end-to-end**

Run: `bin/rails runner "dt = DeploymentTarget.first; puts dt.deploying?; puts dt.lock_version"`
Expected: `false` and `0` — columns exist and have defaults.
