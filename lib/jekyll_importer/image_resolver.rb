module JekyllImporter
  class ImageResolver
    WORDPRESS_SIZE_PATTERN = /-\d+x\d+(?=\.\w+$)/
    THUMBNAIL_SUFFIX_PATTERN = /[_-](?:sml|thumb|thumbnail)(?=\.\w+$)/i

    def initialize(assets_base_path:, image_uploader:)
      @assets_base_path = Pathname.new(assets_base_path)
      @image_uploader = image_uploader
    end

    def resolve_and_upload(src)
      resolved = resolve_local_image(src)
      return missing_placeholder(src) unless resolved

      image_id = @image_uploader.call(resolved)
      return upload_failed_placeholder(src) unless image_id

      { type: "image", image_id: image_id }
    end

    private

    def resolve_local_image(src)
      try_exact(src) || try_without_resize(src) || try_without_thumb_suffix(src) || try_scaled(src)
    end

    def try_exact(src)
      path = @assets_base_path.join(src.delete_prefix("/"))
      path.to_s if path.exist?
    end

    def try_without_resize(src)
      original_src = src.gsub(WORDPRESS_SIZE_PATTERN, "")
      return nil if original_src == src

      path = @assets_base_path.join(original_src.delete_prefix("/"))
      path.to_s if path.exist?
    end

    def try_without_thumb_suffix(src)
      original_src = src.gsub(THUMBNAIL_SUFFIX_PATTERN, "")
      return nil if original_src == src

      path = @assets_base_path.join(original_src.delete_prefix("/"))
      path.to_s if path.exist?
    end

    def try_scaled(src)
      ext = File.extname(src)
      base = src.gsub(WORDPRESS_SIZE_PATTERN, "").delete_suffix(ext)
      path = @assets_base_path.join("#{base.delete_prefix('/')}-scaled#{ext}")
      path.to_s if path.exist?
    end

    def missing_placeholder(src)
      { type: "paragraph", text: "<i>[Missing image: #{src}]</i>" }
    end

    def upload_failed_placeholder(src)
      { type: "paragraph", text: "<i>[Upload failed: #{src}]</i>" }
    end
  end
end
