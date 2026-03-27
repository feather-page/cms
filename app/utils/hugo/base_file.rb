module Hugo
  class BaseFile
    attr_reader :build_path

    def initialize(build_path:)
      @build_path = build_path
    end

    def write
      full_path = build_path.join(relative_path).cleanpath
      unless full_path.to_s.start_with?("#{build_path}/")
        raise ArgumentError, "Path #{full_path} is outside build path #{build_path}"
      end
      FileUtils.mkdir_p(full_path.dirname)
      if binary?
        File.binwrite(full_path, content)
      else
        File.write(full_path, content)
      end
    end

    def relative_path = raise NotImplementedError
    def content = raise NotImplementedError
    def binary? = false
  end
end
