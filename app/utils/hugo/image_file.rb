module Hugo
  class ImageFile < BaseFile
    attr_reader :image_variant

    def initialize(build_path:, image_variant:)
      super(build_path: build_path)
      @image_variant = image_variant
    end

    def relative_path = image_variant.static_path
    def content = image_variant.binary_data
    def binary? = true
  end
end
