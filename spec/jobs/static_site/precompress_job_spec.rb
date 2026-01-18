require "brotli"
require "zlib"

describe StaticSite::PrecompressJob do
  let(:job) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
  end

  describe "#perform" do
    before do
      File.write("#{temp_dir}/index.html", "<html><body>Hello World</body></html>")
      File.write("#{temp_dir}/styles.css", "body { color: red; }")
      File.write("#{temp_dir}/app.js", "console.log('hello');")
      File.write("#{temp_dir}/robots.txt", "User-agent: *")
      File.write("#{temp_dir}/feed.xml", "<rss></rss>")
      File.write("#{temp_dir}/image.png", "binary data")
    end

    it "creates gzip compressed files for text files" do
      job.perform(temp_dir)

      expect(File.exist?("#{temp_dir}/index.html.gz")).to be true
      expect(File.exist?("#{temp_dir}/styles.css.gz")).to be true
      expect(File.exist?("#{temp_dir}/app.js.gz")).to be true
      expect(File.exist?("#{temp_dir}/robots.txt.gz")).to be true
      expect(File.exist?("#{temp_dir}/feed.xml.gz")).to be true
    end

    it "creates brotli compressed files for text files" do
      job.perform(temp_dir)

      expect(File.exist?("#{temp_dir}/index.html.br")).to be true
      expect(File.exist?("#{temp_dir}/styles.css.br")).to be true
      expect(File.exist?("#{temp_dir}/app.js.br")).to be true
      expect(File.exist?("#{temp_dir}/robots.txt.br")).to be true
      expect(File.exist?("#{temp_dir}/feed.xml.br")).to be true
    end

    it "does not compress non-text files" do
      job.perform(temp_dir)

      expect(File.exist?("#{temp_dir}/image.png.gz")).to be false
      expect(File.exist?("#{temp_dir}/image.png.br")).to be false
    end

    it "creates valid gzip files that can be decompressed" do
      job.perform(temp_dir)

      gzip_content = Zlib::GzipReader.open("#{temp_dir}/index.html.gz", &:read)
      expect(gzip_content).to eq("<html><body>Hello World</body></html>")
    end

    it "creates valid brotli files that can be decompressed" do
      job.perform(temp_dir)

      brotli_content = Brotli.inflate(File.binread("#{temp_dir}/index.html.br"))
      expect(brotli_content).to eq("<html><body>Hello World</body></html>")
    end

    it "compresses files in subdirectories" do
      FileUtils.mkdir_p("#{temp_dir}/posts/hello")
      File.write("#{temp_dir}/posts/hello/index.html", "<html>Post</html>")

      job.perform(temp_dir)

      expect(File.exist?("#{temp_dir}/posts/hello/index.html.gz")).to be true
      expect(File.exist?("#{temp_dir}/posts/hello/index.html.br")).to be true
    end
  end
end
