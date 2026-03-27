require "rails_helper"

RSpec.describe Hugo::BaseFile do
  let(:build_path) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(build_path) }

  describe "#write" do
    context "with a text file" do
      let(:file) do
        Class.new(described_class) do
          def relative_path = "content/post.md"
          def content = "---\ntitle: Hello\n---\n"
        end.new(build_path:)
      end

      it "writes content to the correct path" do
        file.write
        written = File.read(build_path.join("content/post.md"))
        expect(written).to eq("---\ntitle: Hello\n---\n")
      end

      it "auto-creates parent directories" do
        file.write
        expect(build_path.join("content")).to be_directory
      end
    end

    context "with a binary file" do
      let(:binary_content) { "\x89PNG\r\n\x1a\n".b }
      let(:file) do
        content = binary_content
        Class.new(described_class) do
          define_method(:relative_path) { "static/images/pic.png" }
          define_method(:content) { content }
          define_method(:binary?) { true }
        end.new(build_path:)
      end

      it "writes binary content" do
        file.write
        written = File.binread(build_path.join("static/images/pic.png"))
        expect(written).to eq(binary_content)
        expect(written.encoding).to eq(Encoding::ASCII_8BIT)
      end
    end

    context "with path traversal" do
      let(:file) do
        Class.new(described_class) do
          def relative_path = "../../etc/passwd"
          def content = "malicious"
        end.new(build_path:)
      end

      it "raises ArgumentError" do
        expect { file.write }.to raise_error(ArgumentError, /outside build path/)
      end
    end
  end

  describe "#relative_path" do
    it "raises NotImplementedError on base class" do
      expect { described_class.new(build_path:).relative_path }.to raise_error(NotImplementedError)
    end
  end

  describe "#content" do
    it "raises NotImplementedError on base class" do
      expect { described_class.new(build_path:).content }.to raise_error(NotImplementedError)
    end
  end

  describe "#binary?" do
    it "defaults to false" do
      expect(described_class.new(build_path:).binary?).to be false
    end
  end
end
