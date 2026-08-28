module StaticSite
  # A sink that records what an export produced, for tests.
  #
  # Written content is kept as a String. Copied files are kept as a Source —
  # only the path, never the bytes — so that image variants (up to 25 MB each,
  # times every entry in Image::Variants) never enter memory. A test that really
  # needs the bytes reads them through Source#read.
  class RecordingSink
    Source = Struct.new(:path) do
      def read = File.binread(path)
    end

    def initialize
      @entries = {}
      @mutex = Mutex.new
    end

    def write(path, content)
      store(path, content)
    end

    def copy(path, from:)
      store(path, Source.new(from))
    end

    def [](path) = @mutex.synchronize { @entries[path] }
    def exist?(path) = @mutex.synchronize { @entries.key?(path) }
    def paths = @mutex.synchronize { @entries.keys.sort }

    private

    def store(path, entry)
      @mutex.synchronize { @entries[path] = entry }
    end
  end
end
