class Image
  class Variants
    SIZES = {
      mobile_x1: 430,
      mobile_x2: 860,
      desktop_x1: 1000,
      mobile_x3: 1290,
      desktop_x2: 2000
    }.freeze
    FORMAT = "webp".freeze

    def self.keys
      @keys ||= (SIZES.keys.map { |name| :"#{name}_#{FORMAT}" } + [:desktop_x1_jpg]).freeze
    end

    def self.key?(variant_key)
      keys.include?(variant_key)
    end

    def self.each_key(&)
      keys.each(&)
    end

    def self.filename_for(variant_key)
      raise ArgumentError, "unknown variant #{variant_key.inspect}" unless key?(variant_key)

      extension = extension_of(variant_key)
      "#{variant_key.to_s.delete_suffix("_#{extension}")}.#{extension}"
    end

    def self.key_from(name, extension)
      key = :"#{name}_#{extension}"
      key if key?(key)
    end

    def self.content_type_for(variant_key)
      extension_of(variant_key) == "jpg" ? "image/jpeg" : "image/webp"
    end

    def self.extension_of(variant_key)
      variant_key.to_s.split("_").last
    end
    private_class_method :extension_of

    def self.options(size:, format:)
      { resize_to_limit: [size, size], format:, saver: { strip: true } }
    end

    def self.configure(attachable)
      attachable.variant :desktop_x1_jpg, **options(size: 1000, format: :jpg)

      SIZES.each do |size_name, size|
        key = :"#{size_name}_#{FORMAT}"
        attachable.variant(key, **options(size:, format: FORMAT))
      end
    end
  end
end
