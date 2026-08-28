module StaticSite
  # A sink that records what an export produced, for tests. Copies are kept as a
  # Source — the path, never the bytes — so image variants stay out of memory.
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
