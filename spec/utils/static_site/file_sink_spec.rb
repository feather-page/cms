require "rails_helper"

RSpec.describe StaticSite::FileSink do
  around do |example|
    Dir.mktmpdir do |tmp|
      @parent_dir = tmp
      example.run
    end
  end

  attr_reader :parent_dir

  let(:sink) { described_class.new(parent_dir) }
  let(:source_dir) { FileUtils.mkdir_p(File.join(parent_dir, "sources")).first }

  def read_back(path) = File.binread(File.join(sink.dir, path))

  it_behaves_like "a sink"

  it "builds inside the given parent directory" do
    expect(File.dirname(sink.dir)).to eq(parent_dir)
    expect(Dir.exist?(sink.dir)).to be true
  end

  it "starts empty" do
    expect(Dir.children(sink.dir)).to be_empty
  end

  it "gets its own directory per instance" do
    other = described_class.new(parent_dir)

    expect(other.dir).not_to eq(sink.dir)
  end

  it "preserves UTF-8 content" do
    sink.write("index.html", "Grüße — ★★★★☆")

    expect(File.read(File.join(sink.dir, "index.html"))).to eq("Grüße — ★★★★☆")
  end

  it "copies bytes unchanged" do
    source = File.join(source_dir, "image.webp")
    bytes = Random.new(42).bytes(2048)
    File.binwrite(source, bytes)

    sink.copy("images/x/desktop.webp", from: source)

    expect(read_back("images/x/desktop.webp")).to eq(bytes)
  end

  describe "#discard!" do
    it "removes the directory" do
      sink.write("index.html", "gone soon")

      sink.discard!

      expect(Dir.exist?(sink.dir)).to be false
    end

    it "is safe after the directory has been moved away" do
      moved = File.join(parent_dir, "moved")
      FileUtils.mv(sink.dir, moved)

      expect { sink.discard! }.not_to raise_error
      expect(Dir.exist?(moved)).to be true
    end
  end
end
