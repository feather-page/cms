# Hugo Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Rails-native ERB rendering with Hugo static site generation, using Hugo's built-in features for sitemap, RSS, taxonomy pages, syntax highlighting, and more.

**Architecture:** The CMS writes a complete Hugo source directory (content files with HTML + shortcodes, data files as JSON, config, images) per deployment target. `hugo build --minify` generates the static output. Existing rclone deployment and deploy locking remain unchanged.

**Tech Stack:** Ruby on Rails 8.1, Hugo (system binary, already in Docker), ViewComponent (block renderers), Solid Queue (jobs), rclone (deployment)

**Spec:** `docs/superpowers/specs/2026-03-27-hugo-rendering-design.md`

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `db/migrate/TIMESTAMP_create_themes.rb` | Create themes table, add theme_id to sites |
| `app/models/theme.rb` | Theme model (name, hugo_theme identifier) |
| `app/utils/hugo/base_file.rb` | Abstract base for all Hugo file generators |
| `app/utils/hugo/config_file.rb` | Generate Hugo config.json |
| `app/utils/hugo/post_file.rb` | Generate post content files |
| `app/utils/hugo/page_file.rb` | Generate page content files |
| `app/utils/hugo/project_file.rb` | Generate project content files |
| `app/utils/hugo/data_file.rb` | Generate data/*.json files (books, projects, site) |
| `app/utils/hugo/image_file.rb` | Copy image variant binaries to static/ |
| `app/utils/hugo/image_variant.rb` | Map image variants to Hugo static paths |
| `app/utils/hugo/theme_linker.rb` | Symlink vendor/themes into source dir |
| `app/components/blocks/renderer/hugo_html.rb` | Base renderer dispatching blocks to Hugo renderers |
| `app/components/blocks/renderer/hugo_html/code.rb` | Code → `highlight` shortcode |
| `app/components/blocks/renderer/hugo_html/image.rb` | Image → `image` shortcode |
| `app/components/blocks/renderer/hugo_html/embed.rb` | Embed → youtube/vimeo/embed shortcode |
| `app/components/blocks/renderer/hugo_html/book.rb` | Book → `book` shortcode |
| `app/jobs/hugo/build_job.rb` | Orchestrate full Hugo build pipeline |
| `vendor/themes/simple_emoji/` | Hugo theme (layouts, shortcodes, partials, CSS) |
| `spec/utils/hugo/*_spec.rb` | Specs for all Hugo file generators |
| `spec/components/blocks/renderer/hugo_html/*_spec.rb` | Specs for Hugo block renderers |
| `spec/jobs/hugo/build_job_spec.rb` | Spec for build job |

### Modified Files

| File | Change |
|------|--------|
| `app/models/site.rb` | Add `belongs_to :theme` association |
| `app/models/concerns/editable.rb` | Add `hugo_html` method |
| `app/models/deployment_target.rb` | Update `build_path`/`source_dir` for new directory structure |
| `app/controllers/previews_controller.rb` | Rewrite to serve static files from Hugo preview output |
| `db/seeds.rb` | Seed initial themes |

### Deleted Files (Final Cleanup)

| File | Reason |
|------|--------|
| `app/jobs/static_site/export_job.rb` | Replaced by Hugo::BuildJob |
| `app/jobs/static_site/page_renderer.rb` | Replaced by Hugo templates |
| `app/jobs/static_site/rss_feed_renderer.rb` | Replaced by Hugo built-in RSS |
| `app/jobs/static_site/image_collector.rb` | Inlined into Hugo::BuildJob |
| `app/jobs/static_site/output_paths.rb` | Hugo handles output paths |
| `app/components/blocks/renderer/static_site_html.rb` | Replaced by HugoHtml |
| `app/components/blocks/renderer/static_site_html/*.rb` | Replaced by HugoHtml renderers |
| `app/views/static_site/*.html.erb` | Replaced by Hugo templates |
| `app/views/layouts/static_site.html.erb` | Replaced by Hugo baseof.html |
| `app/helpers/static_site_helper.rb` | No longer needed |
| `app/controllers/concerns/preview_routing.rb` | Preview is now static file serving |
| `app/controllers/concerns/preview_image_serving.rb` | Images served from Hugo output |
| `app/assets/stylesheets/static_site.css` | Moved into Hugo theme |

---

## Task 1: Theme Model and Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_themes.rb`
- Create: `app/models/theme.rb`
- Modify: `app/models/site.rb`
- Create: `spec/models/theme_spec.rb`
- Modify: `spec/factories/sites.rb`

- [ ] **Step 1: Write the failing test for Theme model**

Create `spec/models/theme_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Theme, type: :model do
  describe "validations" do
    subject { build(:theme) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:hugo_theme) }
    it { is_expected.to validate_uniqueness_of(:hugo_theme) }
  end

  describe "associations" do
    it { is_expected.to have_many(:sites) }
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/theme_spec.rb`
Expected: FAIL — `uninitialized constant Theme`

- [ ] **Step 3: Create the migration**

Generate and edit the migration:

```bash
bundle exec rails generate migration CreateThemes
```

Edit the generated migration file:

```ruby
class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes, id: :uuid do |t|
      t.string :name, null: false
      t.string :hugo_theme, null: false

      t.timestamps
    end

    add_index :themes, :hugo_theme, unique: true

    add_reference :sites, :theme, type: :uuid, foreign_key: true
  end
end
```

- [ ] **Step 4: Run the migration**

Run: `bundle exec rails db:migrate`
Expected: Migration succeeds, `themes` table created, `sites.theme_id` column added.

- [ ] **Step 5: Create the Theme model**

Create `app/models/theme.rb`:

```ruby
class Theme < ApplicationRecord
  has_many :sites, dependent: :restrict_with_error

  validates :name, presence: true
  validates :hugo_theme, presence: true, uniqueness: true
end
```

- [ ] **Step 6: Update Site model**

In `app/models/site.rb`, add the theme association:

```ruby
belongs_to :theme, optional: true
```

- [ ] **Step 7: Create the factory**

Create `spec/factories/themes.rb`:

```ruby
FactoryBot.define do
  factory :theme do
    name { "Simple Emoji" }
    hugo_theme { "simple_emoji" }
  end
end
```

Update `spec/factories/sites.rb` to include theme association:

```ruby
association :theme
```

- [ ] **Step 8: Seed initial theme data**

Add to `db/seeds.rb`:

```ruby
Theme.find_or_create_by!(hugo_theme: "simple_emoji") do |t|
  t.name = "Simple Emoji"
end
```

- [ ] **Step 9: Run tests and verify they pass**

Run: `bundle exec rspec spec/models/theme_spec.rb`
Expected: All tests PASS

Run the full suite to check for regressions from the factory change:

Run: `bundle exec rspec`
Expected: No new failures

- [ ] **Step 10: Commit**

```bash
git add db/migrate/*_create_themes.rb app/models/theme.rb app/models/site.rb \
  spec/models/theme_spec.rb spec/factories/themes.rb spec/factories/sites.rb \
  db/schema.rb db/seeds.rb
git commit -m "feat: add Theme model with migration and Site association"
```

---

## Task 2: Hugo Base File and Image Variant Utilities

**Files:**
- Create: `app/utils/hugo/base_file.rb`
- Create: `app/utils/hugo/image_variant.rb`
- Create: `app/utils/hugo/image_file.rb`
- Create: `app/utils/hugo/theme_linker.rb`
- Create: `spec/utils/hugo/base_file_spec.rb`
- Create: `spec/utils/hugo/image_variant_spec.rb`
- Create: `spec/utils/hugo/theme_linker_spec.rb`

- [ ] **Step 1: Write tests for Hugo::BaseFile**

Create `spec/utils/hugo/base_file_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::BaseFile do
  let(:build_path) { Rails.root.join("tmp", "test_hugo_build") }

  after { FileUtils.rm_rf(build_path) }

  describe "#write" do
    it "writes text content to the correct path" do
      file = Class.new(Hugo::BaseFile) do
        def relative_path = "content/posts/test.html"
        def content = "Hello Hugo"
      end.new(build_path: build_path)

      file.write

      expect(File.read(build_path.join("content/posts/test.html"))).to eq("Hello Hugo")
    end

    it "writes binary content when binary? is true" do
      binary_data = "\xFF\xD8\xFF\xE0".b

      file = Class.new(Hugo::BaseFile) do
        define_method(:relative_path) { "static/images/test.webp" }
        define_method(:content) { binary_data }
        define_method(:binary?) { true }
      end.new(build_path: build_path)

      file.write

      written = File.binread(build_path.join("static/images/test.webp"))
      expect(written).to eq(binary_data)
    end

    it "creates parent directories automatically" do
      file = Class.new(Hugo::BaseFile) do
        def relative_path = "deep/nested/dir/file.txt"
        def content = "nested"
      end.new(build_path: build_path)

      file.write

      expect(File.exist?(build_path.join("deep/nested/dir/file.txt"))).to be true
    end

    it "rejects paths with traversal attempts" do
      file = Class.new(Hugo::BaseFile) do
        def relative_path = "../../../etc/passwd"
        def content = "evil"
      end.new(build_path: build_path)

      expect { file.write }.to raise_error(ArgumentError, /outside build path/)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/utils/hugo/base_file_spec.rb`
Expected: FAIL — `uninitialized constant Hugo::BaseFile`

- [ ] **Step 3: Implement Hugo::BaseFile**

Create `app/utils/hugo/base_file.rb`:

```ruby
module Hugo
  class BaseFile
    attr_reader :build_path

    def initialize(build_path:)
      @build_path = build_path
    end

    def write
      full_path = build_path.join(relative_path).cleanpath
      unless full_path.to_s.start_with?(build_path.to_s)
        raise ArgumentError, "Path #{full_path} is outside build path #{build_path}"
      end

      FileUtils.mkdir_p(full_path.dirname)

      if binary?
        File.binwrite(full_path, content)
      else
        File.write(full_path, content)
      end
    end

    def relative_path
      raise NotImplementedError
    end

    def content
      raise NotImplementedError
    end

    def binary?
      false
    end
  end
end
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `bundle exec rspec spec/utils/hugo/base_file_spec.rb`
Expected: All PASS

- [ ] **Step 5: Write tests for Hugo::ImageVariant**

Create `spec/utils/hugo/image_variant_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::ImageVariant do
  let(:image) { create(:image) }

  describe "#public_path" do
    it "returns the static image path for webp variants" do
      variant = described_class.new(image: image, variant_name: :mobile_x1_webp)
      expect(variant.public_path).to eq("/images/#{image.public_id}/mobile_x1.webp")
    end

    it "returns the static image path for jpg variants" do
      variant = described_class.new(image: image, variant_name: :desktop_x1_jpg)
      expect(variant.public_path).to eq("/images/#{image.public_id}/desktop_x1.jpg")
    end
  end

  describe "#static_path" do
    it "returns the path relative to Hugo source dir" do
      variant = described_class.new(image: image, variant_name: :mobile_x1_webp)
      expect(variant.static_path).to eq("static/images/#{image.public_id}/mobile_x1.webp")
    end
  end

  describe "#binary_data" do
    it "reads the processed variant binary from disk" do
      variant = described_class.new(image: image, variant_name: :mobile_x1_webp)
      # Trigger variant processing
      image.file.variant(:mobile_x1_webp).processed

      data = variant.binary_data
      expect(data).to be_a(String)
      expect(data.encoding).to eq(Encoding::ASCII_8BIT)
    end
  end

  describe ".all_for" do
    it "returns all variant objects for an image" do
      variants = described_class.all_for(image)
      expect(variants.size).to eq(Image::Variants::SIZES.size + 1) # +1 for desktop_x1_jpg
      expect(variants).to all(be_a(described_class))
    end
  end
end
```

- [ ] **Step 6: Implement Hugo::ImageVariant**

Create `app/utils/hugo/image_variant.rb`:

```ruby
module Hugo
  class ImageVariant
    attr_reader :image, :variant_name

    def initialize(image:, variant_name:)
      @image = image
      @variant_name = variant_name
    end

    def public_path
      "/images/#{image.public_id}/#{file_name}"
    end

    def static_path
      "static#{public_path}"
    end

    def binary_data
      File.binread(image.fs_path(variant: variant_name))
    end

    def self.all_for(image)
      Image::Variants.keys.map { |name| new(image: image, variant_name: name) }
    end

    private

    def file_name
      name_part = variant_name.to_s.delete_suffix("_webp").delete_suffix("_jpg")
      extension = variant_name.to_s.end_with?("_jpg") ? "jpg" : "webp"
      "#{name_part}.#{extension}"
    end
  end
end
```

- [ ] **Step 7: Implement Hugo::ImageFile**

Create `app/utils/hugo/image_file.rb`:

```ruby
module Hugo
  class ImageFile < BaseFile
    attr_reader :image_variant

    def initialize(build_path:, image_variant:)
      super(build_path: build_path)
      @image_variant = image_variant
    end

    def relative_path
      image_variant.static_path
    end

    def content
      image_variant.binary_data
    end

    def binary?
      true
    end
  end
end
```

- [ ] **Step 8: Write tests for Hugo::ThemeLinker**

Create `spec/utils/hugo/theme_linker_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::ThemeLinker do
  let(:build_path) { Rails.root.join("tmp", "test_hugo_build") }

  before { FileUtils.mkdir_p(build_path) }
  after { FileUtils.rm_rf(build_path) }

  describe ".link" do
    it "creates a symlink from source themes dir to vendor/themes" do
      described_class.link(build_path: build_path)

      themes_path = build_path.join("themes")
      expect(themes_path).to be_symlink
      expect(File.readlink(themes_path)).to eq(Rails.root.join("vendor/themes").to_s)
    end

    it "replaces existing symlink" do
      FileUtils.ln_s("/old/path", build_path.join("themes"))

      described_class.link(build_path: build_path)

      expect(File.readlink(build_path.join("themes"))).to eq(Rails.root.join("vendor/themes").to_s)
    end
  end
end
```

- [ ] **Step 9: Implement Hugo::ThemeLinker**

Create `app/utils/hugo/theme_linker.rb`:

```ruby
module Hugo
  class ThemeLinker
    def self.link(build_path:)
      themes_link = build_path.join("themes")
      FileUtils.rm_f(themes_link)
      FileUtils.ln_s(Rails.root.join("vendor/themes"), themes_link)
    end
  end
end
```

- [ ] **Step 10: Run all tests and verify**

Run: `bundle exec rspec spec/utils/hugo/`
Expected: All PASS

- [ ] **Step 11: Commit**

```bash
git add app/utils/hugo/base_file.rb app/utils/hugo/image_variant.rb \
  app/utils/hugo/image_file.rb app/utils/hugo/theme_linker.rb \
  spec/utils/hugo/
git commit -m "feat: add Hugo base file, image variant, and theme linker utilities"
```

---

## Task 3: HugoHtml Block Renderer

**Files:**
- Create: `app/components/blocks/renderer/hugo_html.rb`
- Create: `app/components/blocks/renderer/hugo_html/code.rb`
- Create: `app/components/blocks/renderer/hugo_html/image.rb`
- Create: `app/components/blocks/renderer/hugo_html/embed.rb`
- Create: `app/components/blocks/renderer/hugo_html/book.rb`
- Modify: `app/models/concerns/editable.rb`
- Create: `spec/components/blocks/renderer/hugo_html/code_spec.rb`
- Create: `spec/components/blocks/renderer/hugo_html/image_spec.rb`
- Create: `spec/components/blocks/renderer/hugo_html/embed_spec.rb`
- Create: `spec/components/blocks/renderer/hugo_html/book_spec.rb`

- [ ] **Step 1: Write tests for the HugoHtml code renderer**

Create `spec/components/blocks/renderer/hugo_html/code_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Code do
  describe "#to_html" do
    it "renders a Hugo highlight shortcode" do
      block = Blocks::Code.new(id: "1", code: "puts 'hello'", language: "ruby")
      result = described_class.new(block).to_html

      expect(result).to include('{{< highlight ruby >}}')
      expect(result).to include("puts 'hello'")
      expect(result).to include('{{< /highlight >}}')
    end

    it "uses plaintext as default language" do
      block = Blocks::Code.new(id: "1", code: "some text", language: "plaintext")
      result = described_class.new(block).to_html

      expect(result).to include('{{< highlight plaintext >}}')
    end
  end
end
```

- [ ] **Step 2: Write tests for the HugoHtml image renderer**

Create `spec/components/blocks/renderer/hugo_html/image_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Image do
  describe "#to_html" do
    it "renders a Hugo image shortcode with id" do
      image = create(:image)
      block = Blocks::Image.new(id: "1", image_id: image.id, caption: nil)
      result = described_class.new(block).to_html

      expect(result).to include("{{< image")
      expect(result).to include("id=\"#{image.public_id}\"")
      expect(result).to include(">}}")
    end

    it "includes caption when present" do
      image = create(:image)
      block = Blocks::Image.new(id: "1", image_id: image.id, caption: "A nice photo")
      result = described_class.new(block).to_html

      expect(result).to include('caption="A nice photo"')
    end

    it "renders nothing when image_id is nil" do
      block = Blocks::Image.new(id: "1", image_id: nil, caption: nil)
      result = described_class.new(block).to_html

      expect(result).to eq("")
    end
  end
end
```

- [ ] **Step 3: Write tests for the HugoHtml embed renderer**

Create `spec/components/blocks/renderer/hugo_html/embed_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Embed do
  describe "#to_html" do
    it "renders a youtube shortcode for YouTube embeds" do
      block = Blocks::Embed.new(
        id: "1", service: "youtube",
        source: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        embed: "https://www.youtube.com/embed/dQw4w9WgXcQ",
        width: 580, height: 320, caption: nil
      )
      result = described_class.new(block).to_html

      expect(result).to include('{{< youtube dQw4w9WgXcQ >}}')
    end

    it "renders a vimeo shortcode for Vimeo embeds" do
      block = Blocks::Embed.new(
        id: "1", service: "vimeo",
        source: "https://vimeo.com/123456",
        embed: "https://player.vimeo.com/video/123456",
        width: 580, height: 320, caption: nil
      )
      result = described_class.new(block).to_html

      expect(result).to include('{{< vimeo 123456 >}}')
    end

    it "renders a generic embed shortcode for other services" do
      block = Blocks::Embed.new(
        id: "1", service: "other",
        source: "https://example.com",
        embed: "https://example.com/embed",
        width: 580, height: 320, caption: "Example"
      )
      result = described_class.new(block).to_html

      expect(result).to include('{{< embed')
      expect(result).to include('url="https://example.com/embed"')
      expect(result).to include('caption="Example"')
    end
  end
end
```

- [ ] **Step 4: Write tests for the HugoHtml book renderer**

Create `spec/components/blocks/renderer/hugo_html/book_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Blocks::Renderer::HugoHtml::Book do
  describe "#to_html" do
    it "renders a book shortcode with public_id" do
      block = Blocks::Book.new(
        id: "1", book_public_id: "abc123",
        title: "Test Book", author: "Author",
        cover_url: nil, emoji: "📖"
      )
      result = described_class.new(block).to_html

      expect(result).to include('{{< book id="abc123" >}}')
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `bundle exec rspec spec/components/blocks/renderer/hugo_html/`
Expected: FAIL — `uninitialized constant Blocks::Renderer::HugoHtml`

- [ ] **Step 6: Implement the HugoHtml base renderer**

Create `app/components/blocks/renderer/hugo_html.rb`:

```ruby
module Blocks
  module Renderer
    module HugoHtml
      RENDERERS = {
        "code" => "Blocks::Renderer::HugoHtml::Code",
        "image" => "Blocks::Renderer::HugoHtml::Image",
        "embed" => "Blocks::Renderer::HugoHtml::Embed",
        "book" => "Blocks::Renderer::HugoHtml::Book"
      }.freeze

      def self.render(blocks)
        blocks.map { |block|
          renderer_class = RENDERERS[block.type] || Html.renderer_for(block.type)
          renderer_class.constantize.new(block).to_html
        }.join("\n\n").html_safe
      end
    end
  end
end
```

Note: This references `Html.renderer_for` — check how the existing `Html` renderer resolves classes. If it uses a different pattern, match it. The fallback ensures paragraph, header, quote, list, and table blocks use the standard HTML renderers.

- [ ] **Step 7: Implement the code renderer**

Create `app/components/blocks/renderer/hugo_html/code.rb`:

```ruby
module Blocks
  module Renderer
    module HugoHtml
      class Code
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          "{{< highlight #{block.language} >}}\n#{block.code}\n{{< /highlight >}}"
        end
      end
    end
  end
end
```

- [ ] **Step 8: Implement the image renderer**

Create `app/components/blocks/renderer/hugo_html/image.rb`:

```ruby
module Blocks
  module Renderer
    module HugoHtml
      class Image
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          return "" if block.image_id.blank?

          image = ::Image.find(block.image_id)
          params = ["id=\"#{image.public_id}\""]
          params << "caption=\"#{block.caption}\"" if block.caption.present?

          "{{< image #{params.join(' ')} >}}"
        end
      end
    end
  end
end
```

- [ ] **Step 9: Implement the embed renderer**

Create `app/components/blocks/renderer/hugo_html/embed.rb`:

```ruby
module Blocks
  module Renderer
    module HugoHtml
      class Embed
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          case block.service
          when "youtube"
            video_id = extract_youtube_id(block.source)
            "{{< youtube #{video_id} >}}"
          when "vimeo"
            video_id = extract_vimeo_id(block.source)
            "{{< vimeo #{video_id} >}}"
          else
            params = ["url=\"#{block.embed}\""]
            params << "caption=\"#{block.caption}\"" if block.caption.present?
            "{{< embed #{params.join(' ')} >}}"
          end
        end

        private

        def extract_youtube_id(url)
          return "" if url.blank?

          if url.include?("watch?v=")
            url.split("watch?v=").last.split("&").first
          elsif url.include?("youtu.be/")
            url.split("youtu.be/").last.split("?").first
          elsif url.include?("/embed/")
            url.split("/embed/").last.split("?").first
          else
            url
          end
        end

        def extract_vimeo_id(url)
          return "" if url.blank?

          url.split("/").last.split("?").first
        end
      end
    end
  end
end
```

- [ ] **Step 10: Implement the book renderer**

Create `app/components/blocks/renderer/hugo_html/book.rb`:

```ruby
module Blocks
  module Renderer
    module HugoHtml
      class Book
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def to_html
          "{{< book id=\"#{block.book_public_id}\" >}}"
        end
      end
    end
  end
end
```

- [ ] **Step 11: Add hugo_html method to Editable concern**

In `app/models/concerns/editable.rb`, add alongside the existing `static_site_html` method:

```ruby
def hugo_html
  Blocks::Renderer::HugoHtml.render(blocks)
end
```

- [ ] **Step 12: Run tests and verify they pass**

Run: `bundle exec rspec spec/components/blocks/renderer/hugo_html/`
Expected: All PASS

- [ ] **Step 13: Commit**

```bash
git add app/components/blocks/renderer/hugo_html.rb \
  app/components/blocks/renderer/hugo_html/ \
  app/models/concerns/editable.rb \
  spec/components/blocks/renderer/hugo_html/
git commit -m "feat: add HugoHtml block renderer with code, image, embed, book shortcodes"
```

---

## Task 4: Hugo Content File Generators

**Files:**
- Create: `app/utils/hugo/config_file.rb`
- Create: `app/utils/hugo/post_file.rb`
- Create: `app/utils/hugo/page_file.rb`
- Create: `app/utils/hugo/project_file.rb`
- Create: `app/utils/hugo/data_file.rb`
- Create: `spec/utils/hugo/config_file_spec.rb`
- Create: `spec/utils/hugo/post_file_spec.rb`
- Create: `spec/utils/hugo/page_file_spec.rb`
- Create: `spec/utils/hugo/project_file_spec.rb`
- Create: `spec/utils/hugo/data_file_spec.rb`

- [ ] **Step 1: Write tests for Hugo::ConfigFile**

Create `spec/utils/hugo/config_file_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::ConfigFile do
  let(:build_path) { Rails.root.join("tmp", "test_hugo_build") }
  let(:theme) { create(:theme) }
  let(:site) { create(:site, theme: theme) }
  let(:deployment_target) { create(:deployment_target, site: site) }

  after { FileUtils.rm_rf(build_path) }

  describe "#write" do
    it "writes config.json to the build path" do
      file = described_class.new(build_path: build_path, site: site, deployment_target: deployment_target)
      file.write

      config = JSON.parse(File.read(build_path.join("config.json")))
      expect(config["theme"]).to eq("simple_emoji")
      expect(config["title"]).to eq(site.title)
      expect(config["baseURL"]).to include(deployment_target.public_hostname)
      expect(config["taxonomies"]).to eq({ "tag" => "tags" })
      expect(config["minify"]).to be true
    end

    it "includes related content configuration" do
      file = described_class.new(build_path: build_path, site: site, deployment_target: deployment_target)
      file.write

      config = JSON.parse(File.read(build_path.join("config.json")))
      expect(config["related"]["indices"]).to be_an(Array)
      expect(config["related"]["indices"].first["name"]).to eq("tags")
    end

    it "includes output format configuration for RSS" do
      file = described_class.new(build_path: build_path, site: site, deployment_target: deployment_target)
      file.write

      config = JSON.parse(File.read(build_path.join("config.json")))
      expect(config["outputs"]["home"]).to include("RSS")
      expect(config["outputs"]["section"]).to include("RSS")
    end
  end
end
```

- [ ] **Step 2: Implement Hugo::ConfigFile**

Create `app/utils/hugo/config_file.rb`:

```ruby
module Hugo
  class ConfigFile < BaseFile
    attr_reader :site, :deployment_target

    def initialize(build_path:, site:, deployment_target:)
      super(build_path: build_path)
      @site = site
      @deployment_target = deployment_target
    end

    def relative_path
      "config.json"
    end

    def content
      JSON.pretty_generate(config)
    end

    private

    def config
      {
        baseURL: "https://#{deployment_target.public_hostname}/",
        title: site.title,
        languageCode: site.language_code,
        theme: site.theme.hugo_theme,
        copyright: site.copyright,
        enableRobotsTXT: true,
        robotsNoIndex: staging?(deployment_target),
        minify: true,
        taxonomies: { tag: "tags" },
        pagination: { pagerSize: 25 },
        related: {
          threshold: 50,
          includeNewer: true,
          indices: [
            { name: "tags", weight: 100 },
            { name: "date", weight: 10 }
          ]
        },
        outputs: {
          home: %w[HTML RSS],
          section: %w[HTML RSS]
        },
        markup: {
          highlight: {
            style: "monokai",
            lineNos: false,
            noClasses: true
          }
        },
        params: {
          emoji: site.emoji
        }
      }
    end

    def staging?(deployment_target)
      deployment_target.type == "staging"
    end
  end
end
```

Note: The `robotsNoIndex` param is used by the theme's `robots.txt` template to output `Disallow: /` for staging targets. Create `vendor/themes/simple_emoji/layouts/robots.txt`:

```
User-agent: *
{{ if .Site.Params.robotsNoIndex }}Disallow: /{{ else }}Allow: /{{ end }}
Sitemap: {{ "sitemap.xml" | absURL }}
```

- [ ] **Step 3: Write tests for Hugo::PostFile**

Create `spec/utils/hugo/post_file_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::PostFile do
  let(:build_path) { Rails.root.join("tmp", "test_hugo_build") }
  let(:site) { create(:site, :with_theme) }
  let(:post) { create(:post, site: site, title: "Test Post", emoji: "✍️", tags: "ruby, rails") }

  after { FileUtils.rm_rf(build_path) }

  describe "#write" do
    it "writes a content file with JSON front matter and HTML body" do
      file = described_class.new(build_path: build_path, post: post)
      file.write

      content = File.read(build_path.join("content/posts/#{post.slug}.html"))
      front_matter, body = content.split("\n\n", 2)
      meta = JSON.parse(front_matter)

      expect(meta["title"]).to eq("Test Post")
      expect(meta["emoji"]).to eq("✍️")
      expect(meta["tags"]).to eq(["ruby", "rails"])
      expect(meta["draft"]).to be false
    end

    it "sets draft true for unpublished posts" do
      post.update!(draft: true)
      file = described_class.new(build_path: build_path, post: post)
      file.write

      content = File.read(build_path.join("content/posts/#{post.slug}.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["draft"]).to be true
    end

    it "includes publishDate for scheduled posts" do
      future = 1.week.from_now
      post.update!(publish_at: future)
      file = described_class.new(build_path: build_path, post: post)
      file.write

      content = File.read(build_path.join("content/posts/#{post.slug}.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["publishDate"]).to be_present
    end

    it "includes header image data when present" do
      image = create(:image, site: site)
      post.update!(header_image: image)
      file = described_class.new(build_path: build_path, post: post)
      file.write

      content = File.read(build_path.join("content/posts/#{post.slug}.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["header_image"]).to include("url")
      expect(meta["header_image"]["url"]).to include(image.public_id)
    end
  end
end
```

- [ ] **Step 4: Implement Hugo::PostFile**

Create `app/utils/hugo/post_file.rb`:

```ruby
module Hugo
  class PostFile < BaseFile
    attr_reader :post

    def initialize(build_path:, post:)
      super(build_path: build_path)
      @post = post
    end

    def relative_path
      "content/posts/#{post.slug}.html"
    end

    def content
      "#{JSON.pretty_generate(front_matter)}\n\n#{post.hugo_html}"
    end

    private

    def front_matter
      meta = {
        title: post.title,
        date: post.created_at.iso8601,
        url: "/#{post.slug}/",
        draft: post.draft?,
        emoji: post.emoji,
        tags: post.tag_list
      }

      meta[:publishDate] = post.publish_at.iso8601 if post.publish_at.present?
      meta[:summary] = post.content_excerpt if post.content_excerpt.present?

      if post.header_image.present?
        meta[:header_image] = header_image_data(post.header_image)
      end

      if post.book.present?
        meta[:book] = {
          public_id: post.book.public_id,
          title: post.book.title,
          author: post.book.author,
          emoji: post.book.emoji,
          rating: post.book.rating
        }
      end

      meta
    end

    def header_image_data(image)
      {
        url: ImageVariant.new(image: image, variant_name: :desktop_x1_webp).public_path,
        srcset: Image::Variants::SIZES.map { |name, width|
          variant = ImageVariant.new(image: image, variant_name: :"#{name}_webp")
          "#{variant.public_path} #{width}w"
        }.join(", ")
      }
    end
  end
end
```

- [ ] **Step 5: Write tests for Hugo::PageFile**

Create `spec/utils/hugo/page_file_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::PageFile do
  let(:build_path) { Rails.root.join("tmp", "test_hugo_build") }
  let(:site) { create(:site, :with_theme) }
  let(:page) { create(:page, site: site, title: "About", slug: "about") }

  after { FileUtils.rm_rf(build_path) }

  describe "#write" do
    it "writes a page content file" do
      file = described_class.new(build_path: build_path, page: page)
      file.write

      content = File.read(build_path.join("content/pages/about.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["title"]).to eq("About")
    end

    it "uses home layout for the homepage" do
      homepage = create(:page, site: site, slug: "home", title: "Home")
      file = described_class.new(build_path: build_path, page: homepage)
      file.write

      content = File.read(build_path.join("content/pages/home.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["layout"]).to eq("home")
    end

    it "includes menu entry for pages in navigation" do
      navigation = site.main_navigation
      navigation.add(page)

      file = described_class.new(build_path: build_path, page: page)
      file.write

      content = File.read(build_path.join("content/pages/about.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["menu"]).to include("main")
      expect(meta["menu"]["main"]["weight"]).to be_a(Integer)
    end

    it "sets page_type for special pages" do
      books_page = create(:page, site: site, slug: "books", page_type: "books")
      file = described_class.new(build_path: build_path, page: books_page)
      file.write

      content = File.read(build_path.join("content/pages/books.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["page_type"]).to eq("books")
    end
  end
end
```

- [ ] **Step 6: Implement Hugo::PageFile**

Create `app/utils/hugo/page_file.rb`:

```ruby
module Hugo
  class PageFile < BaseFile
    attr_reader :page

    def initialize(build_path:, page:)
      super(build_path: build_path)
      @page = page
    end

    def relative_path
      "content/pages/#{page.slug}.html"
    end

    def content
      "#{JSON.pretty_generate(front_matter)}\n\n#{page.hugo_html}"
    end

    private

    def front_matter
      meta = {
        title: page.title,
        url: "/#{page.slug}/",
        emoji: page.emoji
      }

      meta[:layout] = "home" if page.homepage?
      meta[:page_type] = page.page_type unless page.page_type == "default"

      if page.in_navigation?
        item = page.navigation_items.first
        meta[:menu] = { main: { weight: (item.position + 1) * 10 } }
      end

      if page.header_image.present?
        meta[:header_image] = {
          url: ImageVariant.new(image: page.header_image, variant_name: :desktop_x1_webp).public_path
        }
      end

      meta
    end
  end
end
```

- [ ] **Step 7: Write tests for Hugo::ProjectFile**

Create `spec/utils/hugo/project_file_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::ProjectFile do
  let(:build_path) { Rails.root.join("tmp", "test_hugo_build") }
  let(:site) { create(:site, :with_theme) }
  let(:project) { create(:project, site: site, title: "My Project", slug: "my-project") }

  after { FileUtils.rm_rf(build_path) }

  describe "#write" do
    it "writes a project content file with metadata" do
      file = described_class.new(build_path: build_path, project: project)
      file.write

      content = File.read(build_path.join("content/projects/my-project.html"))
      meta = JSON.parse(content.split("\n\n", 2).first)

      expect(meta["title"]).to eq("My Project")
      expect(meta["layout"]).to eq("project")
      expect(meta["status"]).to be_present
    end
  end
end
```

- [ ] **Step 8: Implement Hugo::ProjectFile**

Create `app/utils/hugo/project_file.rb`:

```ruby
module Hugo
  class ProjectFile < BaseFile
    attr_reader :project

    def initialize(build_path:, project:)
      super(build_path: build_path)
      @project = project
    end

    def relative_path
      "content/projects/#{project.slug}.html"
    end

    def content
      "#{JSON.pretty_generate(front_matter)}\n\n#{project.hugo_html}"
    end

    private

    def front_matter
      meta = {
        title: project.title,
        url: "/projects/#{project.slug}/",
        layout: "project",
        emoji: project.emoji,
        status: project.status,
        status_badge_class: project.status_badge_class,
        project_type: project.project_type,
        short_description: project.short_description,
        tags: project.tag_list
      }

      meta[:company] = project.company if project.company.present?
      meta[:role] = project.role if project.role.present?
      meta[:period] = project.display_period if project.respond_to?(:display_period)
      meta[:links] = project.links if project.links.present?

      if project.header_image.present?
        meta[:header_image] = {
          url: ImageVariant.new(image: project.header_image, variant_name: :desktop_x1_webp).public_path
        }
      end

      if project.thumbnail_image.present?
        meta[:thumbnail] = ImageVariant.new(
          image: project.thumbnail_image, variant_name: :mobile_x1_webp
        ).public_path
      end

      meta
    end
  end
end
```

- [ ] **Step 9: Write tests for Hugo::DataFile**

Create `spec/utils/hugo/data_file_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::DataFile do
  let(:build_path) { Rails.root.join("tmp", "test_hugo_build") }
  let(:site) { create(:site, :with_theme) }

  after { FileUtils.rm_rf(build_path) }

  describe "books data" do
    it "writes books as keyed JSON" do
      book = create(:book, site: site, title: "Test Book", author: "Author", emoji: "📖", rating: 4)
      file = described_class.new(build_path: build_path, site: site, type: :books)
      file.write

      data = JSON.parse(File.read(build_path.join("data/books.json")))
      expect(data[book.public_id]["title"]).to eq("Test Book")
      expect(data[book.public_id]["author"]).to eq("Author")
      expect(data[book.public_id]["rating"]).to eq(4)
    end
  end

  describe "projects data" do
    it "writes projects as keyed JSON" do
      project = create(:project, site: site, title: "CMS", slug: "cms")
      file = described_class.new(build_path: build_path, site: site, type: :projects)
      file.write

      data = JSON.parse(File.read(build_path.join("data/projects.json")))
      expect(data[project.slug]["title"]).to eq("CMS")
      expect(data[project.slug]["status"]).to be_present
    end
  end

  describe "site data" do
    it "writes site settings as JSON" do
      file = described_class.new(build_path: build_path, site: site, type: :site)
      file.write

      data = JSON.parse(File.read(build_path.join("data/site.json")))
      expect(data["title"]).to eq(site.title)
      expect(data["emoji"]).to eq(site.emoji)
    end
  end
end
```

- [ ] **Step 10: Implement Hugo::DataFile**

Create `app/utils/hugo/data_file.rb`:

```ruby
module Hugo
  class DataFile < BaseFile
    attr_reader :site, :type

    def initialize(build_path:, site:, type:)
      super(build_path: build_path)
      @site = site
      @type = type
    end

    def relative_path
      "data/#{type}.json"
    end

    def content
      JSON.pretty_generate(send(:"#{type}_data"))
    end

    private

    def books_data
      site.books.each_with_object({}) do |book, hash|
        hash[book.public_id] = {
          title: book.title,
          author: book.author,
          emoji: book.emoji,
          rating: book.rating,
          reading_status: book.reading_status,
          read_at: book.read_at&.iso8601,
          cover_url: book_cover_url(book)
        }
      end
    end

    def projects_data
      site.projects.each_with_object({}) do |project, hash|
        hash[project.slug] = {
          title: project.title,
          emoji: project.emoji,
          status: project.status,
          status_badge_class: project.status_badge_class,
          project_type: project.project_type,
          short_description: project.short_description,
          period: project.respond_to?(:display_period) ? project.display_period : nil,
          company: project.company,
          role: project.role,
          links: project.links,
          url: "/projects/#{project.slug}/"
        }
      end
    end

    def site_data
      {
        title: site.title,
        emoji: site.emoji,
        language_code: site.language_code,
        domain: site.domain,
        copyright: site.copyright
      }
    end

    def book_cover_url(book)
      return nil unless book.cover_image&.file&.attached?

      ImageVariant.new(image: book.cover_image, variant_name: :mobile_x1_webp).public_path
    end
  end
end
```

- [ ] **Step 11: Run all tests**

Run: `bundle exec rspec spec/utils/hugo/`
Expected: All PASS

- [ ] **Step 12: Commit**

```bash
git add app/utils/hugo/config_file.rb app/utils/hugo/post_file.rb \
  app/utils/hugo/page_file.rb app/utils/hugo/project_file.rb \
  app/utils/hugo/data_file.rb spec/utils/hugo/
git commit -m "feat: add Hugo content file generators (config, post, page, project, data)"
```

---

## Task 5: Hugo Build Job

**Files:**
- Create: `app/jobs/hugo/build_job.rb`
- Create: `spec/jobs/hugo/build_job_spec.rb`

- [ ] **Step 1: Write tests for Hugo::BuildJob**

Create `spec/jobs/hugo/build_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Hugo::BuildJob, type: :job do
  let(:theme) { create(:theme) }
  let(:site) { create(:site, theme: theme) }
  let(:deployment_target) { create(:deployment_target, site: site) }

  before do
    FileUtils.mkdir_p(Rails.root.join("vendor/themes"))
    allow(deployment_target).to receive(:acquire_deploy_lock!).and_return(true)
    allow(deployment_target).to receive(:release_deploy_lock!)
  end

  after { FileUtils.rm_rf(deployment_target.build_path) }

  describe "#perform" do
    it "writes config.json" do
      stub_hugo_command
      described_class.perform_now(deployment_target)

      expect(File.exist?(source_path("config.json"))).to be true
    end

    it "writes content files for published posts" do
      post = create(:post, site: site, title: "Hello", slug: "hello", draft: false)
      stub_hugo_command
      described_class.perform_now(deployment_target)

      expect(File.exist?(source_path("content/posts/hello.html"))).to be true
    end

    it "writes data files" do
      create(:book, site: site)
      stub_hugo_command
      described_class.perform_now(deployment_target)

      expect(File.exist?(source_path("data/books.json"))).to be true
      expect(File.exist?(source_path("data/projects.json"))).to be true
      expect(File.exist?(source_path("data/site.json"))).to be true
    end

    it "creates themes symlink" do
      stub_hugo_command
      described_class.perform_now(deployment_target)

      expect(source_path("themes")).to be_symlink
    end

    it "executes hugo build command" do
      expect_hugo_command
      described_class.perform_now(deployment_target)
    end

    it "runs precompress after hugo build" do
      stub_hugo_command
      expect(StaticSite::PrecompressJob).to receive(:perform_now)
        .with(deployment_target.deploy_output_path.to_s)
      described_class.perform_now(deployment_target)
    end

    it "deploys via rclone" do
      stub_hugo_command
      expect(Rclone::Deployer).to receive(:deploy).with(deployment_target)
      described_class.perform_now(deployment_target)
    end

    it "releases deploy lock in ensure block" do
      stub_hugo_command(success: false)
      expect(deployment_target).to receive(:release_deploy_lock!)

      expect { described_class.perform_now(deployment_target) }.to raise_error(Hugo::BuildJob::HugoBuildError)
    end

    it "skips deploy and precompress in preview mode" do
      stub_hugo_command
      expect(Rclone::Deployer).not_to receive(:deploy)
      expect(StaticSite::PrecompressJob).not_to receive(:perform_now)

      described_class.perform_now(deployment_target, preview: true)
    end

    it "retries lock acquisition up to max attempts" do
      allow(deployment_target).to receive(:acquire_deploy_lock!).and_return(false)

      expect { described_class.perform_now(deployment_target) }
        .to raise_error(Hugo::BuildJob::DeployLockError)
    end
  end

  private

  def source_path(relative)
    deployment_target.build_path.join("source", relative)
  end

  def stub_hugo_command(success: true)
    status = instance_double(Process::Status, success?: success, exitstatus: success ? 0 : 1)
    allow(Open3).to receive(:capture3).and_return(["", "", status])
  end

  def expect_hugo_command
    status = instance_double(Process::Status, success?: true, exitstatus: 0)
    expect(Open3).to receive(:capture3).with(
      hash_including("HOME" => anything),
      "hugo",
      "--source", deployment_target.build_path.join("source").to_s,
      "--destination", deployment_target.deploy_output_path.to_s,
      "--minify",
      hash_including(timeout: anything)
    ).and_return(["", "", status])
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/hugo/build_job_spec.rb`
Expected: FAIL — `uninitialized constant Hugo::BuildJob`

- [ ] **Step 3: Update DeploymentTarget paths**

In `app/models/deployment_target.rb`, update or add path methods to match the new directory structure:

```ruby
def build_path
  Rails.root.join("storage", "hugo", id)
end

def source_path
  build_path.join("source")
end

def deploy_output_path
  build_path.join("deploy")
end

def preview_output_path
  build_path.join("preview")
end

def source_dir
  "#{deploy_output_path}/"
end
```

Note: `source_dir` is what rclone uses as the sync source — it must point to the Hugo output directory, not the Hugo source directory. Keep the trailing slash for rclone compatibility.

- [ ] **Step 4: Implement Hugo::BuildJob**

Create `app/jobs/hugo/build_job.rb`:

```ruby
require "open3"

module Hugo
  class BuildJob < ApplicationJob
    class HugoBuildError < StandardError; end
    class DeployLockError < StandardError; end

    LOCK_RETRY_LIMIT = 60
    LOCK_RETRY_WAIT = 5
    HUGO_TIMEOUT = 60

    queue_as :default

    def perform(deployment_target, preview: false)
      @deployment_target = deployment_target
      @site = deployment_target.site
      @preview = preview
      @build_path = deployment_target.source_path

      acquire_lock! unless preview
      cleanup
      write_source_files
      run_hugo_build(output_path: output_path)
      unless preview
        precompress
        deploy
      end
    ensure
      deployment_target.release_deploy_lock! unless preview
    end

    private

    attr_reader :deployment_target, :site, :build_path

    def acquire_lock!
      LOCK_RETRY_LIMIT.times do
        return if deployment_target.acquire_deploy_lock!
        sleep(LOCK_RETRY_WAIT)
      end

      raise DeployLockError, "Could not acquire deploy lock after #{LOCK_RETRY_LIMIT} attempts"
    end

    def cleanup
      FileUtils.rm_rf(build_path)
      FileUtils.mkdir_p(build_path)
    end

    def write_source_files
      Hugo::ConfigFile.new(
        build_path: build_path, site: site, deployment_target: deployment_target
      ).write

      write_content_files
      write_data_files
      write_image_files
      Hugo::ThemeLinker.link(build_path: build_path)
    end

    def write_content_files
      processor = StaticSite::ParallelProcessor.new(site.posts.published, thread_count: 4)
      processor.process { |post| Hugo::PostFile.new(build_path: build_path, post: post).write }

      processor = StaticSite::ParallelProcessor.new(site.pages.where.not(slug: "home"), thread_count: 4)
      processor.process { |page| Hugo::PageFile.new(build_path: build_path, page: page).write }

      # Homepage
      homepage = site.pages.find_by(slug: "home")
      Hugo::PageFile.new(build_path: build_path, page: homepage).write if homepage

      processor = StaticSite::ParallelProcessor.new(site.projects, thread_count: 4)
      processor.process { |project| Hugo::ProjectFile.new(build_path: build_path, project: project).write }
    end

    def write_data_files
      Hugo::DataFile.new(build_path: build_path, site: site, type: :books).write
      Hugo::DataFile.new(build_path: build_path, site: site, type: :projects).write
      Hugo::DataFile.new(build_path: build_path, site: site, type: :site).write
    end

    def write_image_files
      images = collect_images
      variants = images.flat_map { |image| Hugo::ImageVariant.all_for(image) }

      processor = StaticSite::ParallelProcessor.new(variants, thread_count: 4)
      processor.process do |variant|
        Hugo::ImageFile.new(build_path: build_path, image_variant: variant).write
      rescue => e
        Rails.logger.warn("Failed to write image variant #{variant.public_path}: #{e.message}")
      end
    end

    def collect_images
      images = site.images.assigned.to_a
      images += site.posts.published.filter_map(&:header_image)
      images += site.pages.filter_map(&:header_image)
      images += site.projects.filter_map(&:header_image)
      images += site.projects.filter_map(&:thumbnail_image)
      images += site.books.filter_map(&:cover_image)
      images.uniq
    end

    def run_hugo_build(output_path:)
      stdout, stderr, status = Open3.capture3(
        { "HOME" => Dir.home },
        "hugo",
        "--source", build_path.to_s,
        "--destination", output_path.to_s,
        "--minify",
        timeout: HUGO_TIMEOUT
      )

      unless status.success?
        Rails.logger.error("Hugo build failed (exit #{status.exitstatus}): #{stderr}")
        raise HugoBuildError, "Hugo build failed: #{stderr.truncate(500)}"
      end

      Rails.logger.info("Hugo build succeeded: #{stdout}")
    end

    def precompress
      StaticSite::PrecompressJob.perform_now(output_path.to_s)
    end

    def deploy
      Rclone::Deployer.deploy(deployment_target)
    end

    def output_path
      @preview ? deployment_target.preview_output_path : deployment_target.deploy_output_path
    end
  end
end
```

- [ ] **Step 5: Run tests and verify they pass**

Run: `bundle exec rspec spec/jobs/hugo/build_job_spec.rb`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add app/jobs/hugo/build_job.rb app/models/deployment_target.rb \
  spec/jobs/hugo/build_job_spec.rb
git commit -m "feat: add Hugo::BuildJob with parallel file writing and deploy pipeline"
```

---

## Task 6: Hugo Theme — `simple_emoji`

**Files:**
- Create: `vendor/themes/simple_emoji/theme.toml`
- Create: `vendor/themes/simple_emoji/layouts/_default/baseof.html`
- Create: `vendor/themes/simple_emoji/layouts/_default/home.html`
- Create: `vendor/themes/simple_emoji/layouts/_default/single.html`
- Create: `vendor/themes/simple_emoji/layouts/_default/list.html`
- Create: `vendor/themes/simple_emoji/layouts/posts/single.html`
- Create: `vendor/themes/simple_emoji/layouts/projects/single.html`
- Create: `vendor/themes/simple_emoji/layouts/partials/head.html`
- Create: `vendor/themes/simple_emoji/layouts/partials/nav.html`
- Create: `vendor/themes/simple_emoji/layouts/partials/footer.html`
- Create: `vendor/themes/simple_emoji/layouts/partials/related.html`
- Create: `vendor/themes/simple_emoji/layouts/partials/image.html`
- Create: `vendor/themes/simple_emoji/layouts/shortcodes/image.html`
- Create: `vendor/themes/simple_emoji/layouts/shortcodes/book.html`
- Create: `vendor/themes/simple_emoji/layouts/shortcodes/embed.html`
- Create: `vendor/themes/simple_emoji/layouts/shortcodes/highlight.html` (if needed, otherwise Hugo built-in)
- Create: `vendor/themes/simple_emoji/static/css/style.css`

This task is large but cohesive — it's one theme that must work as a unit. Build it layout by layout, testing with a local Hugo build after each piece.

- [ ] **Step 1: Create theme.toml and directory structure**

Create `vendor/themes/simple_emoji/theme.toml`:

```toml
name = "Simple Emoji"
license = "MIT"
description = "A clean, emoji-focused theme for personal sites"
min_version = "0.120.0"

[author]
  name = "Feather-Page"
```

Create all required directories:

```bash
mkdir -p vendor/themes/simple_emoji/{layouts/{_default,posts,projects,partials,shortcodes,taxonomy},static/css}
```

- [ ] **Step 2: Create the base layout**

Create `vendor/themes/simple_emoji/layouts/_default/baseof.html`:

Base this on the original `simple_emoji` theme from git history (before commit 1630147), but extend with:
- OG/Twitter Card meta tags via head partial
- Support for header images with responsive srcset
- Updated nav with Hugo menu system
- Footer with copyright year substitution
- Dark mode support

The layout should reference:
- `{{ partial "head.html" . }}` for meta tags
- `{{ partial "nav.html" . }}` for navigation
- `{{ partial "footer.html" . }}` for footer
- `{{ block "main" . }}{{ end }}` for content
- Inline CSS from `static/css/style.css` using Hugo Pipes: `{{ $css := resources.Get "css/style.css" | minify }}` or inline via `{{ readFile }}` approach

Refer to the current `app/views/layouts/static_site.html.erb` for the HTML structure and `app/assets/stylesheets/static_site.css` for the CSS (move this file to `vendor/themes/simple_emoji/static/css/style.css`).

- [ ] **Step 3: Create partials**

Create `vendor/themes/simple_emoji/layouts/partials/head.html`:

```html
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{ if not .IsHome }}{{ .Title }} — {{ end }}{{ .Site.Title }}</title>
{{ template "_internal/opengraph.html" . }}
{{ template "_internal/twitter_cards.html" . }}
{{ template "_internal/schema.html" . }}
<link rel="alternate" type="application/rss+xml" title="{{ .Site.Title }}" href="{{ "index.xml" | absURL }}">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>{{ .Site.Params.emoji }}</text></svg>">
```

Create `vendor/themes/simple_emoji/layouts/partials/nav.html`:

```html
<nav>
  <a href="/" class="site-title">{{ .Site.Params.emoji }} {{ .Site.Title }}</a>
  {{ if not .IsHome }}
    <span class="separator">/</span>
    {{ with .Params.emoji }}<span class="page-emoji">{{ . }}</span>{{ end }}
    <span class="page-title">{{ .Title }}</span>
  {{ end }}
  {{ range .Site.Menus.main }}
    <a href="{{ .URL }}" class="nav-link">{{ .Name }}</a>
  {{ end }}
</nav>
```

Create `vendor/themes/simple_emoji/layouts/partials/footer.html`:

```html
<footer>
  <p>{{ replace .Site.Copyright "{{CurrentYear}}" (now.Format "2006") }}</p>
</footer>
```

Create `vendor/themes/simple_emoji/layouts/partials/related.html`:

```html
{{ $related := .Site.RegularPages.Related . | first 5 }}
{{ with $related }}
<section class="related-posts">
  <h2>Related Posts</h2>
  <ul>
    {{ range . }}
    <li><a href="{{ .RelPermalink }}">{{ with .Params.emoji }}{{ . }} {{ end }}{{ .Title }}</a></li>
    {{ end }}
  </ul>
</section>
{{ end }}
```

Create `vendor/themes/simple_emoji/layouts/partials/image.html`:

This partial renders a responsive `<picture>` element. It receives an image public_id and generates srcset from known variant paths:

```html
{{ $id := .id }}
{{ $caption := .caption }}
<figure>
  <picture>
    <source type="image/webp" srcset="/images/{{ $id }}/mobile_x1.webp 430w, /images/{{ $id }}/mobile_x2.webp 860w, /images/{{ $id }}/desktop_x1.webp 1000w, /images/{{ $id }}/mobile_x3.webp 1290w, /images/{{ $id }}/desktop_x2.webp 2000w">
    <img src="/images/{{ $id }}/desktop_x1.webp" alt="{{ $caption }}" loading="lazy">
  </picture>
  {{ with $caption }}<figcaption>{{ . }}</figcaption>{{ end }}
</figure>
```

- [ ] **Step 4: Create shortcodes**

Create `vendor/themes/simple_emoji/layouts/shortcodes/image.html`:

```html
{{ partial "image.html" (dict "id" (.Get "id") "caption" (.Get "caption")) }}
```

Create `vendor/themes/simple_emoji/layouts/shortcodes/book.html`:

```html
{{ $id := .Get "id" }}
{{ $book := index .Site.Data.books $id }}
{{ with $book }}
<div class="book-card book-card--detail">
  {{ if .cover_url }}
    <img src="{{ .cover_url }}" alt="{{ .title }}" class="book-cover" loading="lazy">
  {{ else }}
    <span class="book-emoji">{{ .emoji }}</span>
  {{ end }}
  <div class="book-info">
    <strong>{{ .title }}</strong>
    <span class="book-author">{{ .author }}</span>
    {{ if .rating }}
      <span class="book-rating">{{ range seq .rating }}★{{ end }}{{ range seq (sub 5 .rating) }}☆{{ end }}</span>
    {{ end }}
  </div>
</div>
{{ end }}
```

Create `vendor/themes/simple_emoji/layouts/shortcodes/embed.html`:

```html
<figure class="embed">
  <iframe src="{{ .Get "url" }}" width="100%" height="400" frameborder="0" allowfullscreen loading="lazy"></iframe>
  {{ with .Get "caption" }}<figcaption>{{ . }}</figcaption>{{ end }}
</figure>
```

- [ ] **Step 5: Create the home layout**

Create `vendor/themes/simple_emoji/layouts/_default/home.html`:

```html
{{ define "main" }}
<div class="home-content">
  {{ .Content }}
</div>

<hr>

<section class="posts">
  <h2>Blogposts</h2>
  {{ $paginator := .Paginate (where .Site.RegularPages "Section" "posts") }}
  {{ range $paginator.Pages }}
    <article class="post-summary">
      {{ if .Title }}
        <div class="post-long">
          <a href="{{ .RelPermalink }}">{{ with .Params.emoji }}{{ . }} {{ end }}{{ .Title }}</a>
          <p class="post-excerpt">{{ .Summary }}</p>
          {{ with .Params.thumbnail }}
            <img src="{{ . }}" alt="" class="post-thumbnail" loading="lazy">
          {{ end }}
          <time>{{ .Date.Format "02.01.2006" }}</time>
          {{ with .Params.tags }}
            <div class="tags">{{ range . }}<span class="tag">{{ . }}</span>{{ end }}</div>
          {{ end }}
        </div>
      {{ else }}
        <div class="post-short">
          {{ with .Params.emoji }}<span class="emoji">{{ . }}</span>{{ end }}
          <div class="post-content">{{ .Content }}</div>
          <time>{{ .Date.Format "02.01.2006" }}</time>
        </div>
      {{ end }}
    </article>
  {{ end }}

  {{ template "_internal/pagination.html" . }}
</section>
{{ end }}
```

- [ ] **Step 6: Create the post single layout**

Create `vendor/themes/simple_emoji/layouts/posts/single.html`:

```html
{{ define "main" }}
{{ with .Params.book }}
  {{ $book := index $.Site.Data.books .public_id }}
  {{ with $book }}
    <div class="book-card">
      {{ if .cover_url }}<img src="{{ .cover_url }}" alt="{{ .title }}" class="book-cover">{{ end }}
      <div class="book-info">
        <strong>{{ .title }}</strong>
        <span class="book-author">{{ .author }}</span>
      </div>
    </div>
  {{ end }}
{{ end }}

<article class="post">
  {{ .Content }}
</article>

<footer class="post-meta">
  <time>{{ .Date.Format "02.01.2006" }}</time>
  {{ with .Params.tags }}
    <div class="tags">{{ range . }}<a href="{{ "/tags/" | relURL }}{{ . | urlize }}/" class="tag">{{ . }}</a>{{ end }}</div>
  {{ end }}
</footer>

{{ partial "related.html" . }}
{{ end }}
```

- [ ] **Step 7: Create the project single layout**

Create `vendor/themes/simple_emoji/layouts/projects/single.html`:

```html
{{ define "main" }}
<article class="project">
  <div class="project-meta">
    {{ with .Params.status }}<span class="badge badge--{{ $.Params.status_badge_class }}">{{ . }}</span>{{ end }}
    {{ with .Params.company }}<span class="project-company">{{ . }}</span>{{ end }}
    {{ with .Params.period }}<span class="project-period">{{ . }}</span>{{ end }}
  </div>

  {{ with .Params.role }}<p class="project-role">{{ . }}</p>{{ end }}
  {{ with .Params.short_description }}<p class="project-description">{{ . }}</p>{{ end }}

  {{ .Content }}

  {{ with .Params.links }}
  <div class="project-links">
    {{ range $name, $url := . }}
      <a href="{{ $url }}" class="project-link" target="_blank" rel="noopener">{{ $name }}</a>
    {{ end }}
  </div>
  {{ end }}

  {{ with .Params.tags }}
    <div class="tags">{{ range . }}<span class="tag">{{ . }}</span>{{ end }}</div>
  {{ end }}
</article>
{{ end }}
```

- [ ] **Step 8: Create the default single and list layouts**

Create `vendor/themes/simple_emoji/layouts/_default/single.html`:

```html
{{ define "main" }}
<article>
  {{ .Content }}
</article>

{{ with .Params.tags }}
  <div class="tags">{{ range . }}<span class="tag">{{ . }}</span>{{ end }}</div>
{{ end }}

{{ if eq .Params.page_type "books" }}
  {{ partial "books-list.html" . }}
{{ else if eq .Params.page_type "projects" }}
  {{ partial "projects-list.html" . }}
{{ end }}
{{ end }}
```

Create `vendor/themes/simple_emoji/layouts/_default/list.html`:

```html
{{ define "main" }}
<div class="list-content">
  {{ .Content }}
</div>

{{ $paginator := .Paginate .Pages }}
{{ range $paginator.Pages }}
  <article class="list-item">
    <a href="{{ .RelPermalink }}">{{ with .Params.emoji }}{{ . }} {{ end }}{{ .Title }}</a>
    <p>{{ .Summary }}</p>
  </article>
{{ end }}

{{ template "_internal/pagination.html" . }}
{{ end }}
```

- [ ] **Step 9: Create taxonomy layout**

Create `vendor/themes/simple_emoji/layouts/taxonomy/tag.html`:

```html
{{ define "main" }}
<h2>Posts tagged "{{ .Title }}"</h2>

{{ range .Pages }}
  <article class="list-item">
    <a href="{{ .RelPermalink }}">{{ with .Params.emoji }}{{ . }} {{ end }}{{ .Title }}</a>
    <time>{{ .Date.Format "02.01.2006" }}</time>
  </article>
{{ end }}
{{ end }}
```

Create `vendor/themes/simple_emoji/layouts/taxonomy/tags.html`:

```html
{{ define "main" }}
<h2>Tags</h2>
<div class="tags">
  {{ range .Pages }}
    <a href="{{ .RelPermalink }}" class="tag">{{ .Title }} ({{ .Count }})</a>
  {{ end }}
</div>
{{ end }}
```

- [ ] **Step 10: Move CSS to theme**

Copy `app/assets/stylesheets/static_site.css` to `vendor/themes/simple_emoji/static/css/style.css`. This is the same CSS, now served by Hugo from the theme's static directory instead of being inlined by Rails.

- [ ] **Step 11: Test the theme with a manual Hugo build**

Create a minimal test site and run Hugo locally to verify the theme works:

```bash
mkdir -p tmp/hugo_test/{content/posts,data,static}
echo '{"title":"Test","date":"2026-01-01","tags":["test"]}

<p>Hello world</p>' > tmp/hugo_test/content/posts/test.html
echo '{"baseURL":"http://localhost/","theme":"simple_emoji","title":"Test Site","taxonomies":{"tag":"tags"},"params":{"emoji":"🧪"}}' > tmp/hugo_test/config.json
echo '{}' > tmp/hugo_test/data/books.json
echo '{}' > tmp/hugo_test/data/projects.json
echo '{"title":"Test","emoji":"🧪"}' > tmp/hugo_test/data/site.json
ln -sf $(pwd)/vendor/themes tmp/hugo_test/themes
hugo --source tmp/hugo_test --destination tmp/hugo_test/public --minify
```

Expected: Hugo builds without errors, output in `tmp/hugo_test/public/`.

Verify:
- `tmp/hugo_test/public/index.html` exists (home page)
- `tmp/hugo_test/public/test/index.html` exists (post)
- `tmp/hugo_test/public/sitemap.xml` exists
- `tmp/hugo_test/public/index.xml` exists (RSS)
- `tmp/hugo_test/public/tags/index.html` exists (taxonomy)

```bash
rm -rf tmp/hugo_test
```

- [ ] **Step 12: Commit**

```bash
git add vendor/themes/simple_emoji/
git commit -m "feat: add simple_emoji Hugo theme with layouts, shortcodes, and partials"
```

---

## Task 7: Preview Controller Rewrite

**Files:**
- Modify: `app/controllers/previews_controller.rb`
- Modify: `spec/requests/previews_controller_spec.rb`

- [ ] **Step 1: Write tests for the new PreviewsController**

Rewrite `spec/requests/previews_controller_spec.rb` to test static file serving:

```ruby
require "rails_helper"

RSpec.describe "Previews", type: :request do
  let(:theme) { create(:theme) }
  let(:site) { create(:site, theme: theme) }
  let(:deployment_target) { create(:deployment_target, site: site) }
  let(:preview_path) { deployment_target.preview_output_path }

  before do
    sign_in create(:user, site: site)
    FileUtils.mkdir_p(preview_path)
  end

  after { FileUtils.rm_rf(deployment_target.build_path) }

  describe "GET /preview/:deployment_target_id" do
    it "triggers a Hugo preview build and serves index.html" do
      allow(Hugo::BuildJob).to receive(:perform_now) do |target, preview:|
        FileUtils.mkdir_p(preview_path)
        File.write(preview_path.join("index.html"), "<html><body>Home</body></html>")
      end

      get "/preview/#{deployment_target.public_id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Home")
    end

    it "serves nested paths from preview directory" do
      FileUtils.mkdir_p(preview_path.join("posts/hello"))
      File.write(preview_path.join("posts/hello/index.html"), "<html><body>Post</body></html>")

      allow(Hugo::BuildJob).to receive(:perform_now)

      get "/preview/#{deployment_target.public_id}/posts/hello/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Post")
    end

    it "returns 404 for missing files" do
      allow(Hugo::BuildJob).to receive(:perform_now)

      get "/preview/#{deployment_target.public_id}/nonexistent"

      expect(response).to have_http_status(:not_found)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/previews_controller_spec.rb`
Expected: FAIL — controller still uses old ERB rendering

- [ ] **Step 3: Rewrite PreviewsController**

Replace the contents of `app/controllers/previews_controller.rb`:

```ruby
class PreviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_deployment_target

  def show
    Hugo::BuildJob.perform_now(@deployment_target, preview: true)
    serve_static_file
  end

  private

  def set_deployment_target
    @deployment_target = current_user.site.deployment_targets.find_by!(public_id: params[:deployment_target_id])
  end

  def serve_static_file
    path = params[:path] || ""
    file_path = resolve_file_path(path)

    if file_path && File.exist?(file_path)
      content_type = Rack::Mime.mime_type(File.extname(file_path), "text/html")
      send_file file_path, type: content_type, disposition: "inline"
    else
      head :not_found
    end
  end

  def resolve_file_path(path)
    preview_root = @deployment_target.preview_output_path

    # Try exact path first, then with index.html
    candidates = [
      preview_root.join(path),
      preview_root.join(path, "index.html")
    ]

    found = candidates.find { |p| p.cleanpath.to_s.start_with?(preview_root.to_s) && File.file?(p) }
    found&.to_s
  end
end
```

- [ ] **Step 4: Update routes if needed**

Check `config/routes.rb` for the preview route pattern. It should support a catch-all path segment. If the current route doesn't support `*path`, update it:

```ruby
get "preview/:deployment_target_id(/*path)", to: "previews#show", as: :preview
```

- [ ] **Step 5: Run tests and verify**

Run: `bundle exec rspec spec/requests/previews_controller_spec.rb`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/previews_controller.rb spec/requests/previews_controller_spec.rb config/routes.rb
git commit -m "feat: rewrite PreviewsController to serve Hugo preview output as static files"
```

---

## Task 8: Wire Up Deploy to Hugo::BuildJob

**Files:**
- Modify: `app/models/deployment_target.rb`
- Modify: existing deploy trigger code (check how `deploy` is currently called)

- [ ] **Step 1: Find where deploy is triggered**

Check `app/models/deployment_target.rb` for the `deploy` method and any controller that calls it. The current flow likely calls `StaticSite::ExportJob.perform_later(deployment_target)`. Replace this with `Hugo::BuildJob.perform_later(deployment_target)`.

- [ ] **Step 2: Update the deploy trigger**

In `app/models/deployment_target.rb`, update the `deploy` method:

```ruby
def deploy
  Hugo::BuildJob.perform_later(self)
end
```

- [ ] **Step 3: Run existing deploy-related tests**

Run: `bundle exec rspec spec/models/deployment_target_spec.rb`
Expected: PASS (the deploy method just enqueues a job)

Run the full test suite to check for any references to `StaticSite::ExportJob`:

Run: `bundle exec rspec`
Expected: Note any failures related to `StaticSite::ExportJob` — these will be addressed in the cleanup task.

- [ ] **Step 4: Commit**

```bash
git add app/models/deployment_target.rb
git commit -m "feat: wire deploy trigger to Hugo::BuildJob"
```

---

## Task 9: Integration Test

**Files:**
- Create: `spec/jobs/hugo/integration_spec.rb`

- [ ] **Step 1: Write an integration test for the full pipeline**

Create `spec/jobs/hugo/integration_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Hugo build integration", type: :job do
  let(:theme) { create(:theme) }
  let(:site) { create(:site, theme: theme) }
  let(:deployment_target) { create(:deployment_target, site: site) }

  before do
    FileUtils.mkdir_p(Rails.root.join("vendor/themes"))
  end

  after { FileUtils.rm_rf(deployment_target.build_path) }

  it "writes a complete Hugo source directory" do
    post = create(:post, site: site, title: "Hello World", slug: "hello", draft: false, tags: "ruby")
    page = create(:page, site: site, title: "About", slug: "about")
    project = create(:project, site: site, title: "CMS", slug: "cms")
    create(:book, site: site, title: "Test Book")

    # Add page to navigation
    site.main_navigation.add(page)

    # Stub Hugo binary and deploy, test only file generation
    allow(Open3).to receive(:capture3).and_return(["", "", instance_double(Process::Status, success?: true, exitstatus: 0)])
    allow(Rclone::Deployer).to receive(:deploy)
    allow(StaticSite::PrecompressJob).to receive(:perform_now)
    allow(deployment_target).to receive(:acquire_deploy_lock!).and_return(true)
    allow(deployment_target).to receive(:release_deploy_lock!)

    Hugo::BuildJob.perform_now(deployment_target)

    source = deployment_target.source_path

    # Config
    config = JSON.parse(File.read(source.join("config.json")))
    expect(config["theme"]).to eq("simple_emoji")

    # Post
    post_content = File.read(source.join("content/posts/hello.html"))
    post_meta = JSON.parse(post_content.split("\n\n", 2).first)
    expect(post_meta["title"]).to eq("Hello World")
    expect(post_meta["tags"]).to eq(["ruby"])

    # Page with menu
    page_content = File.read(source.join("content/pages/about.html"))
    page_meta = JSON.parse(page_content.split("\n\n", 2).first)
    expect(page_meta["menu"]).to include("main")

    # Project
    project_content = File.read(source.join("content/projects/cms.html"))
    project_meta = JSON.parse(project_content.split("\n\n", 2).first)
    expect(project_meta["layout"]).to eq("project")

    # Data files
    books_data = JSON.parse(File.read(source.join("data/books.json")))
    expect(books_data.values.first["title"]).to eq("Test Book")

    # Themes symlink
    expect(source.join("themes")).to be_symlink
  end
end
```

Note: You may need to extract `write_source_files` into a testable method or test the BuildJob more directly. Adjust based on the actual implementation.

- [ ] **Step 2: Run integration test**

Run: `bundle exec rspec spec/jobs/hugo/integration_spec.rb`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add spec/jobs/hugo/integration_spec.rb
git commit -m "test: add Hugo build integration test"
```

---

## Task 10: Cleanup — Remove Rails-Native Rendering

**Files:**
- Delete: `app/jobs/static_site/export_job.rb`
- Delete: `app/jobs/static_site/page_renderer.rb`
- Delete: `app/jobs/static_site/rss_feed_renderer.rb`
- Delete: `app/jobs/static_site/image_collector.rb`
- Delete: `app/jobs/static_site/output_paths.rb`
- Delete: `app/components/blocks/renderer/static_site_html.rb`
- Delete: `app/components/blocks/renderer/static_site_html/` (directory)
- Delete: `app/views/static_site/` (directory)
- Delete: `app/views/layouts/static_site.html.erb`
- Delete: `app/helpers/static_site_helper.rb`
- Delete: `app/controllers/concerns/preview_routing.rb`
- Delete: `app/controllers/concerns/preview_image_serving.rb`
- Delete: `app/assets/stylesheets/static_site.css`
- Delete: `spec/jobs/static_site/export_job_spec.rb`
- Delete: associated static_site specs
- Modify: `app/models/concerns/editable.rb` — remove `static_site_html`
- Modify: `app/components/static_site/books_list_component.rb` — remove if unused
- Create: `docs/architecture/decisions/006-restore-hugo-rendering.md`

- [ ] **Step 1: Remove StaticSite files**

```bash
rm -rf app/jobs/static_site/export_job.rb \
  app/jobs/static_site/page_renderer.rb \
  app/jobs/static_site/rss_feed_renderer.rb \
  app/jobs/static_site/image_collector.rb \
  app/jobs/static_site/output_paths.rb
rm -rf app/components/blocks/renderer/static_site_html.rb \
  app/components/blocks/renderer/static_site_html/
rm -rf app/views/static_site/ \
  app/views/layouts/static_site.html.erb
rm -f app/helpers/static_site_helper.rb \
  app/controllers/concerns/preview_routing.rb \
  app/controllers/concerns/preview_image_serving.rb \
  app/assets/stylesheets/static_site.css
```

- [ ] **Step 2: Remove associated specs**

```bash
rm -f spec/jobs/static_site/export_job_spec.rb
rm -rf spec/components/blocks/renderer/static_site_html/
```

Find and remove any other static_site-specific specs.

- [ ] **Step 3: Update Editable concern**

In `app/models/concerns/editable.rb`, remove the `static_site_html` method. Keep `hugo_html` and `content_html`.

- [ ] **Step 4: Remove PreviewRouting and PreviewImageServing includes**

Check if `PreviewsController` still includes these concerns and remove the includes if present.

- [ ] **Step 5: Write ADR for Hugo return**

Create `docs/architecture/decisions/006-restore-hugo-rendering.md`:

```markdown
# 6. Restore Hugo for Static Site Rendering

Date: 2026-03-27

## Status

Accepted (supersedes ADR-005)

## Context

The Rails-native ERB rendering introduced in ADR-005 had performance issues with large content sets and required hand-building features that Hugo provides out of the box (syntax highlighting, sitemap, RSS feeds, taxonomy pages, related content).

## Decision

Replace ERB rendering with Hugo. The CMS writes Hugo source files (content, config, data, images) and invokes `hugo build`. This leverages Hugo's theme ecosystem, built-in features, and fast build times.

## Consequences

- Hugo binary is a system dependency (already in Docker image)
- Themes are curated and stored in `vendor/themes/`
- Content blocks render as a mix of HTML and Hugo shortcodes
- Preview uses on-demand Hugo builds instead of live Rails rendering
- Deployment pipeline (rclone, deploy locking) remains unchanged
```

- [ ] **Step 6: Mark ADR-005 as superseded**

In `docs/architecture/decisions/005-replace-hugo-with-rails-rendering.md`, update the status:

```markdown
## Status

Superseded by [ADR-006](006-restore-hugo-rendering.md)
```

- [ ] **Step 7: Run the full test suite**

Run: `bundle exec rspec`
Expected: All PASS. If any tests reference removed files, fix or remove them.

Run: `bundle exec cucumber` (if cucumber tests exist)
Expected: Check for failures related to static site rendering and fix.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: remove Rails-native rendering, replaced by Hugo (ADR-006)"
```

---

## Task 11: Final Verification

- [ ] **Step 1: Run the full test suite**

```bash
bundle exec rspec
bundle exec cucumber
```

Expected: All PASS

- [ ] **Step 2: Test a full deploy cycle locally (if possible)**

If you have a local deployment target configured, trigger a deploy and verify:

```bash
bundle exec rails console
site = Site.first
target = site.deployment_targets.first
Hugo::BuildJob.perform_now(target)
```

Verify:
- Hugo source files written correctly
- Hugo build completes without errors
- Output contains sitemap.xml, index.xml (RSS), tag pages
- Rclone sync succeeds (or skip if no target configured)

- [ ] **Step 3: Test preview**

Visit the preview URL in the browser and verify the site renders correctly.

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "fix: final adjustments from integration testing"
```
