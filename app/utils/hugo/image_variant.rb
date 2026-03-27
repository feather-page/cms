module Hugo
  class ImageVariant
    attr_reader :image, :variant_name

    def initialize(image:, variant_name:)
      @image = image
      @variant_name = variant_name
    end

    def public_path
      "/images/#{image.public_id}/#{file_name}"
    end

    def static_path
      "static#{public_path}"
    end

    def binary_data
      File.binread(image.fs_path(variant: variant_name))
    end

    def self.all_for(image)
      Image::Variants.keys.map { |name| new(image: image, variant_name: name) }
    end

    private

    def file_name
      name_part = variant_name.to_s.delete_suffix("_webp").delete_suffix("_jpg")
      extension = variant_name.to_s.end_with?("_jpg") ? "jpg" : "webp"
      "#{name_part}.#{extension}"
    end
  end
end
