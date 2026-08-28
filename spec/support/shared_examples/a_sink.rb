# The sink contract from docs/adr/0006-export-writes-through-a-sink.md.
RSpec.shared_examples "a sink" do
  it "accepts written content" do
    sink.write("index.html", "<h1>Hello</h1>")

    expect(read_back("index.html")).to eq("<h1>Hello</h1>")
  end

  it "accepts written content at a nested path" do
    sink.write("posts/my-post/index.html", "nested")

    expect(read_back("posts/my-post/index.html")).to eq("nested")
  end

  it "accepts a copy of an existing file" do
    source = File.join(source_dir, "cover.png")
    File.binwrite(source, "\x89PNG binary".b)

    sink.copy("images/abc/desktop.png", from: source)

    expect(read_back("images/abc/desktop.png")).to eq("\x89PNG binary".b)
  end

  it "writes from several threads at once" do
    paths = Array.new(40) { |i| "posts/post-#{i}/index.html" }

    StaticSite::ParallelProcessor.new(paths, thread_count: 4).process do |path|
      sink.write(path, path)
    end

    expect(paths.map { |path| read_back(path) }).to eq(paths)
  end

  it "exposes only the contract plus its own extras" do
    expect(sink).to respond_to(:write, :copy)
  end
end
