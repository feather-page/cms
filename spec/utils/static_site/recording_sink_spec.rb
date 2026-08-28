require "rails_helper"

RSpec.describe StaticSite::RecordingSink do
  around do |example|
    Dir.mktmpdir { |tmp| @source_dir = tmp and example.run }
  end

  attr_reader :source_dir

  let(:sink) { described_class.new }

  def read_back(path)
    entry = sink[path]
    entry.is_a?(described_class::Source) ? entry.read : entry
  end

  it_behaves_like "a sink"

  it "keeps written content as a string" do
    sink.write("feed.xml", "<?xml ...")

    expect(sink["feed.xml"]).to eq("<?xml ...")
  end

  it "records a copy as a source reference instead of reading the bytes" do
    source = File.join(source_dir, "huge.webp")
    File.binwrite(source, "x" * 1024)

    sink.copy("images/abc/desktop.webp", from: source)

    expect(sink["images/abc/desktop.webp"]).to eq(described_class::Source.new(source))
  end

  it "does not read a copied file, even when the source is gone" do
    source = File.join(source_dir, "vanishing.webp")
    File.binwrite(source, "bytes")
    sink.copy("images/abc/desktop.webp", from: source)

    FileUtils.rm(source)

    expect(sink["images/abc/desktop.webp"].path).to eq(source)
  end

  it "reads a copied file lazily when a test asks for the bytes" do
    source = File.join(source_dir, "cover.webp")
    File.binwrite(source, "real bytes")
    sink.copy("images/abc/desktop.webp", from: source)

    expect(sink["images/abc/desktop.webp"].read).to eq("real bytes")
  end

  describe "#paths" do
    it "lists every path in a stable order, whatever the write order was" do
      sink.write("index.html", "a")
      sink.write("feed.xml", "b")
      sink.copy("images/x.webp", from: __FILE__)

      expect(sink.paths).to eq(["feed.xml", "images/x.webp", "index.html"])
    end

    it "is empty for a fresh sink" do
      expect(sink.paths).to be_empty
    end
  end

  describe "#exist?" do
    it "is true for a written path and false otherwise" do
      sink.write("index.html", "a")

      expect(sink.exist?("index.html")).to be true
      expect(sink.exist?("page/2/index.html")).to be false
    end
  end

  it "records every write when several threads write at once" do
    paths = Array.new(200) { |i| "posts/post-#{i}/index.html" }

    StaticSite::ParallelProcessor.new(paths, thread_count: 4).process { |path| sink.write(path, path) }

    expect(sink.paths).to match_array(paths)
  end
end
