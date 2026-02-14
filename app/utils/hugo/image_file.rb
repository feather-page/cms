# frozen_string_literal: true

module Hugo
  class ImageFile < BaseFile
    delegate :variant, :image, to: :object

    def binary?
      true
    end

    def relative_path
      @object.build_path
    end

    def content
      @object.binary_image
    end
  end
end
