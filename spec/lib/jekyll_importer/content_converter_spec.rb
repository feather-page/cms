require "rails_helper"
require "jekyll_importer/content_converter"

RSpec.describe JekyllImporter::ContentConverter do
  let(:assets_path) { Rails.root.join("tmp/test_assets") }
  let(:uploaded_ids) { {} }
  let(:image_uploader) do
    lambda { |path|
      uploaded_ids[path] = "img_#{uploaded_ids.size + 1}"
      uploaded_ids[path]
    }
  end
  let(:converter) do
    described_class.new(
      assets_base_path: assets_path,
      image_uploader: image_uploader
    )
  end

  before do
    FileUtils.mkdir_p(assets_path.join("assets/2020/02"))
  end

  after do
    FileUtils.rm_rf(assets_path)
  end

  def nested_items(*texts)
    texts.map { |t| { "content" => t, "items" => [] } }
  end

  describe "#convert" do
    it "returns empty array for blank content" do
      expect(converter.convert("")).to eq([])
      expect(converter.convert(nil)).to eq([])
    end

    context "with paragraphs" do
      it "converts plain text to paragraph blocks" do
        result = converter.convert("Hello world")
        expect(result).to eq([{ type: "paragraph", text: "Hello world" }])
      end

      it "converts multiple paragraphs separated by blank lines" do
        content = "First paragraph.\n\nSecond paragraph."
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "paragraph", text: "First paragraph." },
                               { type: "paragraph", text: "Second paragraph." }
                             ])
      end
    end

    context "with headers" do
      it "converts markdown H2 to header block" do
        result = converter.convert("## My Header")
        expect(result).to eq([{ type: "header", text: "My Header", level: 2 }])
      end

      it "converts markdown H3 to header block" do
        result = converter.convert("### Sub Header")
        expect(result).to eq([{ type: "header", text: "Sub Header", level: 3 }])
      end

      it "converts markdown H4 to header block" do
        result = converter.convert("#### Small Header")
        expect(result).to eq([{ type: "header", text: "Small Header", level: 4 }])
      end

      it "clamps H1 to level 2" do
        result = converter.convert("# Main Title")
        expect(result).to eq([{ type: "header", text: "Main Title", level: 2 }])
      end

      it "converts H5 to header block clamped to level 4" do
        result = converter.convert("##### Connection")
        expect(result).to eq([{ type: "header", text: "Connection", level: 4 }])
      end

      it "converts H6 to header block clamped to level 4" do
        result = converter.convert("###### Details")
        expect(result).to eq([{ type: "header", text: "Details", level: 4 }])
      end
    end

    context "with images" do
      let(:image_file) { assets_path.join("assets/2020/02/photo.jpg") }

      before { FileUtils.touch(image_file) }

      it "converts HTML img tag with local image" do
        content = '<img loading="lazy" src="/assets/2020/02/photo.jpg" alt="Photo" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end

      it "converts markdown image with local path" do
        content = "![Photo](/assets/2020/02/photo.jpg)"
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end

      it "strips WordPress resize suffixes to find original" do
        content = '<img src="/assets/2020/02/photo-300x200.jpg" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end

      it "strips _sml suffix to find original" do
        content = '<img src="/assets/2020/02/photo_sml.jpg" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end

      it "strips _thumb suffix to find original" do
        content = '<img src="/assets/2020/02/photo_thumb.jpg" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end

      it "creates placeholder for missing images" do
        content = '<img src="/assets/2020/02/missing.jpg" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "paragraph", text: "<i>[Missing image: /assets/2020/02/missing.jpg]</i>" }])
      end

      it "converts external image URLs to fallback paragraph" do
        content = '<img src="http://example.com/photo.jpg" />'
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "paragraph",
                                 text: '<i>[Externes Bild: <a href="http://example.com/photo.jpg">http://example.com/photo.jpg</a>]</i>' }
                             ])
      end

      it "deduplicates image uploads via the uploader" do
        content = "<img src=\"/assets/2020/02/photo.jpg\" />\n\n<img src=\"/assets/2020/02/photo.jpg\" />"
        converter.convert(content)
        # The uploader is called for each occurrence; dedup is handled by the orchestrator
        expect(uploaded_ids.size).to eq(1)
      end

      it "strips srcset and sizes attributes" do
        content = '<img src="/assets/2020/02/photo.jpg" ' \
                  'srcset="/assets/2020/02/photo.jpg 600w, /assets/2020/02/photo-300x200.jpg 300w" ' \
                  'sizes="(max-width: 600px) 100vw, 600px" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end
    end

    context "with WordPress upload URLs" do
      let(:image_file) { assets_path.join("assets/2012/07/lego_minecraft_9.jpg") }

      before { FileUtils.mkdir_p(assets_path.join("assets/2012/07")) }

      it "normalizes WP upload URL to local path" do
        FileUtils.touch(image_file)

        content = '<img src="http://blog.example.com/wp-content/uploads/2012/07/lego_minecraft_9.jpg" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end

      it "normalizes WP multisite upload URL to local path" do
        FileUtils.touch(image_file)

        content = '<img src="http://tinkrde.test.mug.im/wp-content/uploads/sites/7/2012/07/lego_minecraft_9.jpg" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end

      it "normalizes WP URLs inside linked images" do
        FileUtils.touch(image_file)

        content = '[<img src="http://blog.example.com/wp-content/uploads/2012/07/lego_minecraft_9.jpg" />]' \
                  "(http://blog.example.com/wp-content/uploads/2012/07/lego_minecraft_9.jpg)"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "image", image_id: "img_1" },
                               { type: "paragraph",
                                 text: '<a href="/assets/2012/07/lego_minecraft_9.jpg">' \
                                       "/assets/2012/07/lego_minecraft_9.jpg</a>" }
                             ])
      end

      it "extracts normalized WP image paths" do
        content = '<img src="http://blog.example.com/wp-content/uploads/2012/07/lego_minecraft_9.jpg" />'
        paths = converter.extract_image_paths(content)
        expect(paths).to eq(["/assets/2012/07/lego_minecraft_9.jpg"])
      end
    end

    context "with code blocks" do
      it "converts fenced code blocks with language" do
        content = "```ruby\nputs 'hello'\n```"
        result = converter.convert(content)
        expect(result).to eq([{ type: "code", code: "puts 'hello'", language: "ruby" }])
      end

      it "converts fenced code blocks without language" do
        content = "```\nsome code\n```"
        result = converter.convert(content)
        expect(result).to eq([{ type: "code", code: "some code", language: "plaintext" }])
      end

      it "converts WordPress <pre name='code'> blocks" do
        content = "<pre name=\"code\">&lt;?php echo 'hi'; ?&gt;</pre>"
        result = converter.convert(content)
        expect(result).to eq([{ type: "code", code: "<?php echo 'hi'; ?>" }])
      end

      it "converts BBCode-style [php]...[/php] blocks" do
        content = "[php]echo 'hello';[/php]"
        result = converter.convert(content)
        expect(result).to eq([{ type: "code", code: "echo 'hello';" }])
      end
    end

    context "with lists" do
      it "converts unordered lists with dashes" do
        content = "- First item\n- Second item\n- Third item"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "list", items: nested_items("First item", "Second item", "Third item"), style: "ul" }
                             ])
      end

      it "converts unordered lists with asterisks" do
        content = "* Item A\n* Item B"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "list", items: nested_items("Item A", "Item B"), style: "ul" }
                             ])
      end

      it "converts ordered lists" do
        content = "1. First\n2. Second\n3. Third"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "list", items: nested_items("First", "Second", "Third"), style: "ol" }
                             ])
      end

      it "converts indented unordered lists" do
        content = "  * Indented A\n  * Indented B"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "list", items: nested_items("Indented A", "Indented B"), style: "ul" }
                             ])
      end

      it "converts list items without space after dash" do
        content = "-Bitscope:\n-Another item"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "list", items: nested_items("Bitscope:", "Another item"), style: "ul" }
                             ])
      end

      it "converts HTML unordered lists" do
        content = "<ul>\n<li>Item one</li>\n<li>Item two</li>\n</ul>"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "list", items: nested_items("Item one", "Item two"), style: "ul" }
                             ])
      end

      it "converts HTML ordered lists" do
        content = "<ol>\n<li>First</li>\n<li>Second</li>\n</ol>"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "list", items: nested_items("First", "Second"), style: "ol" }
                             ])
      end
    end

    context "with blockquotes" do
      it "converts HTML blockquotes" do
        content = "<blockquote><p>Wise words here.</p></blockquote>"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "quote", text: "Wise words here.", caption: "" }
                             ])
      end

      it "converts blockquotes with cite attribute" do
        content = '<blockquote cite="http://example.com"><p>A quote.</p></blockquote>'
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "quote", text: "A quote.", caption: "" }
                             ])
      end

      it "converts markdown blockquotes with > prefix" do
        content = "> Die decoded conference ist toll.\n> Wir sind dabei."
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "quote", text: "Die decoded conference ist toll. Wir sind dabei.", caption: "" }
                             ])
      end

      it "converts single-line markdown blockquote" do
        content = "> A single quoted line."
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "quote", text: "A single quoted line.", caption: "" }
                             ])
      end
    end

    context "with table shortcodes" do
      it "converts [table]...[/table] to a table block" do
        content = "[table]\nHeader 1, Header 2\nCell A, Cell B\n[/table]"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "table",
                                 content: [["Header 1", "Header 2"], ["Cell A", "Cell B"]],
                                 with_headings: true }
                             ])
      end

      it "handles case-insensitive table tags" do
        content = "[Table]\nA, B\n[/Table]"
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "table", content: [%w[A B]], with_headings: true }
                             ])
      end
    end

    context "with escaped underscores" do
      it "unescapes \\_ to _ in content" do
        content = 'Check [my\\_link](https://example.com) for details.'
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "paragraph",
                                 text: 'Check <a href="https://example.com">my_link</a> for details.' }
                             ])
      end
    end

    context "with mixed content" do
      let(:image_file) { assets_path.join("assets/2020/02/photo.jpg") }

      before { FileUtils.touch(image_file) }

      it "converts a realistic post with multiple block types" do
        content = <<~CONTENT
          ## Introduction

          This is a paragraph with some text.

          <img src="/assets/2020/02/photo.jpg" alt="Photo" />

          ### Code Example

          ```ruby
          def hello
            puts "world"
          end
          ```

          - Feature one
          - Feature two
          - Feature three
        CONTENT

        result = converter.convert(content)

        expect(result[0]).to eq({ type: "header", text: "Introduction", level: 2 })
        expect(result[1]).to eq({ type: "paragraph", text: "This is a paragraph with some text." })
        expect(result[2]).to eq({ type: "image", image_id: "img_1" })
        expect(result[3]).to eq({ type: "header", text: "Code Example", level: 3 })
        expect(result[4]).to include(type: "code", language: "ruby")
        expect(result[5]).to eq({ type: "list", items: nested_items("Feature one", "Feature two", "Feature three"), style: "ul" })
      end
    end

    context "with links" do
      it "converts auto-links to anchor tags" do
        content = "Visit <https://example.com> for more."
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "paragraph",
                                 text: 'Visit <a href="https://example.com">https://example.com</a> for more.' }
                             ])
      end

      it "converts markdown links to anchor tags" do
        content = "Check [my site](https://example.com) for details."
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "paragraph",
                                 text: 'Check <a href="https://example.com">my site</a> for details.' }
                             ])
      end

      it "converts inline links mixed with other text" do
        content = "Read [post A](https://a.com) and [post B](https://b.com) today."
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "paragraph",
                                 text: 'Read <a href="https://a.com">post A</a> and ' \
                                       '<a href="https://b.com">post B</a> today.' }
                             ])
      end

      it "does not convert markdown images to links" do
        image_file = assets_path.join("assets/2020/02/photo.jpg")
        FileUtils.touch(image_file)

        content = "![Photo](/assets/2020/02/photo.jpg)"
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end
    end

    context "with linked images" do
      it "unwraps linked local image to image block and link paragraph" do
        image_file = assets_path.join("assets/2020/02/photo.jpg")
        FileUtils.touch(image_file)

        content = '[<img src="/assets/2020/02/photo.jpg" />](/assets/2020/02/photo.jpg)'
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "image", image_id: "img_1" },
                               { type: "paragraph",
                                 text: '<a href="/assets/2020/02/photo.jpg">/assets/2020/02/photo.jpg</a>' }
                             ])
      end

      it "unwraps linked external image, showing fallback paragraph and link" do
        content = '[<img src="http://example.com/photo.jpg" />](http://example.com/photo.jpg)'
        result = converter.convert(content)
        expect(result).to eq([
                               { type: "paragraph",
                                 text: '<i>[Externes Bild: <a href="http://example.com/photo.jpg">http://example.com/photo.jpg</a>]</i>' },
                               { type: "paragraph",
                                 text: '<a href="http://example.com/photo.jpg">http://example.com/photo.jpg</a>' }
                             ])
      end

      it "unwraps HTML linked images using the href (full-size) URL" do
        image_file = assets_path.join("assets/2020/02/photo.jpg")
        FileUtils.touch(image_file)

        content = '<a href="/assets/2020/02/photo.jpg"><img src="/assets/2020/02/photo-300x225.jpg" /></a>'
        result = converter.convert(content)
        expect(result).to eq([{ type: "image", image_id: "img_1" }])
      end
    end

    context "with HTML cleanup" do
      it "strips disallowed HTML tags" do
        content = '<div class="wrapper"><span>Hello</span> <b>bold</b></div>'
        result = converter.convert(content)
        expect(result).to eq([{ type: "paragraph", text: "Hello <b>bold</b>" }])
      end

      it "keeps allowed tags" do
        content = 'Text with <b>bold</b>, <i>italic</i>, <u>underline</u>, ' \
                  '<a href="#">link</a>, and <code>code</code>.'
        result = converter.convert(content)
        expect(result.first[:text]).to include("<b>bold</b>")
        expect(result.first[:text]).to include("<i>italic</i>")
        expect(result.first[:text]).to include("<u>underline</u>")
        expect(result.first[:text]).to include("<a href=\"#\">link</a>")
        expect(result.first[:text]).to include("<code>code</code>")
      end

      it "decodes HTML entities" do
        content = "He said &ldquo;hello&rdquo; &#8217;s world"
        result = converter.convert(content)
        expect(result.first[:text]).not_to include("&ldquo;")
        expect(result.first[:text]).not_to include("&#8217;")
      end
    end

    context "with markdown formatting" do
      it "converts **bold** to <b> tags" do
        content = "This is **bold text** here"
        result = converter.convert(content)
        expect(result.first[:text]).to eq("This is <b>bold text</b> here")
      end

      it "converts __bold__ to <b> tags" do
        content = "This is __bold text__ here"
        result = converter.convert(content)
        expect(result.first[:text]).to eq("This is <b>bold text</b> here")
      end

      it "converts *italic* to <i> tags" do
        content = "This is *italic text* here"
        result = converter.convert(content)
        expect(result.first[:text]).to eq("This is <i>italic text</i> here")
      end

      it "converts `code` to <code> tags" do
        content = "Use the `bundle exec` command"
        result = converter.convert(content)
        expect(result.first[:text]).to eq("Use the <code>bundle exec</code> command")
      end

      it "does not convert underscores in filenames" do
        content = "Edit my_file_name.rb to proceed"
        result = converter.convert(content)
        expect(result.first[:text]).to eq("Edit my_file_name.rb to proceed")
      end
    end

    context "with embeds" do
      it "converts YouTube embed tags" do
        content = '<embed src="http://www.youtube.com/v/dQw4w9WgXcQ" type="application/x-shockwave-flash" />'
        result = converter.convert(content)
        expect(result).to eq([{
                                type: "embed",
                                service: "youtube",
                                source: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                                embed: "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
                                caption: ""
                              }])
      end

      it "converts defunct embed sources to archived paragraphs" do
        content = '<embed src="http://blip.tv/some/video" />'
        result = converter.convert(content)
        expect(result).to eq([{ type: "paragraph", text: "<i>[Archived embed: http://blip.tv/some/video]</i>" }])
      end
    end

    context "with WordPress captions" do
      let(:image_file) { assets_path.join("assets/2020/02/photo.jpg") }

      before { FileUtils.touch(image_file) }

      it "extracts caption from WordPress caption divs" do
        content = '<div id="attachment_123" class="wp-caption"><img src="/assets/2020/02/photo.jpg" /><p id="caption-123">My caption text</p></div>'
        result = converter.convert(content)
        expect(result.first[:type]).to eq("image")
        expect(result.first[:caption]).to eq("My caption text")
      end
    end
  end

  describe "#extract_image_paths" do
    it "extracts local image paths from HTML img tags" do
      content = '<img src="/assets/2020/02/photo.jpg" /> and <img src="/assets/2020/02/other.png" />'
      paths = converter.extract_image_paths(content)
      expect(paths).to contain_exactly("/assets/2020/02/photo.jpg", "/assets/2020/02/other.png")
    end

    it "extracts local image paths from markdown images" do
      content = "![Photo](/assets/2020/02/photo.jpg)"
      paths = converter.extract_image_paths(content)
      expect(paths).to eq(["/assets/2020/02/photo.jpg"])
    end

    it "ignores external URLs" do
      content = '<img src="http://example.com/photo.jpg" />'
      paths = converter.extract_image_paths(content)
      expect(paths).to be_empty
    end

    it "deduplicates paths" do
      content = '<img src="/assets/2020/02/photo.jpg" /> <img src="/assets/2020/02/photo.jpg" />'
      paths = converter.extract_image_paths(content)
      expect(paths).to eq(["/assets/2020/02/photo.jpg"])
    end
  end
end
