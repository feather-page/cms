class FeatherDump
  # Copies the original Active Storage blob of each image to images/<public_id>/<filename> inside
  # the dump and describes it for images.json. Variants are not copied; they can be regenerated.
  class ImageFiles
    attr_reader :copied, :missing

    def initialize(dir:, warn:)
      @dir = dir
      @warn = warn
      @copied = 0
      @missing = []
    end

    # Returns the "file" object of an images.json row, or nil when the image has no attachment.
    # When the blob exists but its file cannot be read, the metadata is kept and "path" is null.
    def dump(image)
      unless image.file.attached?
        log_missing("image #{image.public_id}: no file attached")
        return nil
      end

      blob = image.file.blob
      path = File.join("images", image.public_id, blob.filename.sanitized)
      { "path" => (path if copy(blob, image, @dir.join(path))) }.merge(metadata(blob))
    end

    private

    def metadata(blob)
      {
        "filename" => blob.filename.to_s,
        "content_type" => blob.content_type,
        "byte_size" => blob.byte_size,
        "checksum" => blob.checksum,
        "width" => blob.metadata["width"],
        "height" => blob.metadata["height"]
      }
    end

    def copy(blob, image, destination)
      FileUtils.mkdir_p(destination.dirname)
      blob.open { |file| FileUtils.cp(file.path, destination) }
      @copied += 1
    rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError => e
      log_missing("image #{image.public_id}: blob #{blob.key} could not be copied (#{e.class})")
      false
    end

    def log_missing(message)
      @missing << message
      @warn.call(message)
    end
  end
end
