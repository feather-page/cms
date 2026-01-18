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
