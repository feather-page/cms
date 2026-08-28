require "tmpdir"

module StaticSite
  # A sink backed by a fresh temporary directory.
  #
  # The directory is created inside +parent_dir+ so that it shares a filesystem
  # with the export's final destination and can be moved into place cheaply.
  #
  # #dir and #discard! are specific to this implementation and are not part of
  # the sink contract — only #write and #copy are.
  #
  # Thread-safe without locking: FileUtils.mkdir_p tolerates concurrent creation
  # of the same directory, and the export never writes the same path twice.
  class FileSink
    attr_reader :dir

    def initialize(parent_dir)
      FileUtils.mkdir_p(parent_dir)
      @dir = Dir.mktmpdir("export-", parent_dir)
    end

    def write(path, content)
      File.write(prepare(path), content)
    end

    def copy(path, from:)
      FileUtils.cp(from, prepare(path))
    end

    # Removes the directory. Safe to call after it has been moved away, which is
    # why the job can call it unconditionally in an ensure block.
    def discard!
      FileUtils.rm_rf(dir)
    end

    private

    def prepare(path)
      File.join(dir, path).tap { |full| FileUtils.mkdir_p(File.dirname(full)) }
    end
  end
end
