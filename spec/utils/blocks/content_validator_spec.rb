require "rails_helper"

RSpec.describe Blocks::ContentValidator do
  before { described_class.reset_schemas! }

  describe "#valid?" do
    context "with valid paragraph block" do
      it "returns true" do
        validator = described_class.new([{ "type" => "paragraph", "text" => "Hello world" }])

        expect(validator.valid?).to be true
      end
    end

    context "with valid header block" do
      it "returns true" do
        validator = described_class.new([{ "type" => "header", "text" => "Title", "level" => 2 }])

        expect(validator.valid?).to be true
      end
    end

    context "with valid code block" do
      it "returns true" do
        validator = described_class.new([{ "type" => "code", "code" => "puts 'hi'" }])

        expect(validator.valid?).to be true
      end
    end

    context "with valid quote block" do
      it "returns true" do
        content = [{ "type" => "quote", "text" => "To be or not to be", "caption" => "Shakespeare" }]
        validator = described_class.new(content)

        expect(validator.valid?).to be true
      end
    end

    context "with valid list block" do
      it "returns true" do
        content = [{ "type" => "list", "style" => "ul", "items" => %w[one two three] }]
        validator = described_class.new(content)

        expect(validator.valid?).to be true
      end
    end

    context "with valid table block" do
      it "returns true" do
        content = [{ "type" => "table", "content" => [%w[A B], %w[1 2]], "with_headings" => true }]
        validator = described_class.new(content)

        expect(validator.valid?).to be true
      end
    end

    context "with valid image block" do
      it "returns true" do
        validator = described_class.new([{ "type" => "image", "image_id" => "abc123xyz456" }])

        expect(validator.valid?).to be true
      end
    end

    context "with valid book block" do
      it "returns true" do
        validator = described_class.new([{ "type" => "book", "book_public_id" => "abc123" }])

        expect(validator.valid?).to be true
      end
    end

    context "with multiple valid blocks" do
      it "returns true" do
        content = [
          { "type" => "header", "text" => "Title", "level" => 2 },
          { "type" => "paragraph", "text" => "Some text" },
          { "type" => "code", "code" => "x = 1", "language" => "ruby" }
        ]
        validator = described_class.new(content)

        expect(validator.valid?).to be true
      end
    end

    context "with empty content" do
      it "returns true" do
        validator = described_class.new([])

        expect(validator.valid?).to be true
      end
    end

    context "with unknown block type" do
      it "returns false with error" do
        validator = described_class.new([{ "type" => "unknown", "data" => "test" }])

        expect(validator.valid?).to be false
        expect(validator.errors.first).to include("unknown or missing type")
      end
    end

    context "with missing type" do
      it "returns false with error" do
        validator = described_class.new([{ "text" => "no type" }])

        expect(validator.valid?).to be false
        expect(validator.errors.first).to include("unknown or missing type")
      end
    end

    context "with header missing level" do
      it "returns false with error" do
        validator = described_class.new([{ "type" => "header", "text" => "Title" }])

        expect(validator.valid?).to be false
        expect(validator.errors.first).to include("Block 0 (header)")
      end
    end

    context "with header invalid level" do
      it "returns false with error" do
        validator = described_class.new([{ "type" => "header", "text" => "Title", "level" => 1 }])

        expect(validator.valid?).to be false
        expect(validator.errors.first).to include("Block 0 (header)")
      end
    end

    context "with non-array content" do
      it "returns false with error" do
        validator = described_class.new("not an array")

        expect(validator.valid?).to be false
        expect(validator.errors.first).to include("must be an array")
      end
    end
  end

  describe "#normalized_content" do
    it "auto-generates ids for blocks without ids" do
      validator = described_class.new([{ "type" => "paragraph", "text" => "Hello" }])
      validator.valid?

      expect(validator.normalized_content.first[:id]).to be_present
    end

    it "preserves existing ids" do
      validator = described_class.new([{ "type" => "paragraph", "text" => "Hello", "id" => "my-id" }])
      validator.valid?

      expect(validator.normalized_content.first[:id]).to eq("my-id")
    end

    it "returns symbolized keys" do
      validator = described_class.new([{ "type" => "paragraph", "text" => "Hello" }])
      validator.valid?

      block = validator.normalized_content.first
      expect(block).to have_key(:type)
      expect(block).to have_key(:text)
    end
  end
end
