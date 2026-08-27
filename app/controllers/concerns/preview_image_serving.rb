module PreviewImageServing
  extend ActiveSupport::Concern

  private

  def serve_preview_image(image, variant)
    file_path = image.fs_path(variant:)
    return head(:not_found) unless file_path && File.exist?(file_path)

    send_file(file_path, type: Image::Variants.content_type_for(variant), disposition: :inline)
  end
end
