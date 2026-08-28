require "tmpdir"

module StaticSite
  # A sink backed by a fresh temporary directory inside +parent_dir+, so that it
  # shares a filesystem with the export's destination and can be moved there cheaply.
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

    def discard!
      FileUtils.rm_rf(dir)
    end

    private

    def prepare(path)
      File.join(dir, path).tap { |full| FileUtils.mkdir_p(File.dirname(full)) }
    end
  end
end
