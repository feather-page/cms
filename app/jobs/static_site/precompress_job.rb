require "brotli"
require "zlib"

module StaticSite
  class PrecompressJob < ApplicationJob
    THREAD_COUNT = 4

    queue_as :default

    def perform(static_website_path)
      files = text_files(static_website_path)
      ParallelProcessor.new(files, thread_count: THREAD_COUNT).process do |file|
        gzip_compress(file)
        brotli_compress(file)
      end
    end

    private

    def text_files(static_website_path)
      Dir.glob("#{static_website_path}/**/*.{html,css,js,txt,xml}")
    end

    def brotli_compress(file)
      File.binwrite(
        "#{file}.br",
        Brotli.deflate(File.read(file))
      )
    end

    def gzip_compress(file)
      Zlib::GzipWriter.open("#{file}.gz") do |gz|
        gz.write File.read(file)
      end
    end
  end
end
