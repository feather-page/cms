module PreviewImageServing
  extend ActiveSupport::Concern

  private

  def serve_preview_image
    image = find_image
    return head(:not_found) unless image

    variant_key = extract_variant_key
    return head(:not_found) unless valid_variant?(variant_key)

    file_path = image.fs_path(variant: variant_key)
    return head(:not_found) unless file_path && File.exist?(file_path)

    send_file(file_path, type: image_content_type(variant_key), disposition: :inline)
  end

  def find_image
    return nil unless requested_path =~ %r{^images/([^/]+)/}

    site.images.find_by(public_id: ::Regexp.last_match(1))
  end

  def extract_variant_key
    # Handle path with extension in URL
    if requested_path =~ %r{images/[^/]+/([^.]+)\.(webp|jpg)$}
      return :"#{::Regexp.last_match(1)}_#{::Regexp.last_match(2)}"
    end

    # Handle path where extension was parsed as format by Rails routes
    if requested_path =~ %r{images/[^/]+/([^/]+)$}
      variant_name = ::Regexp.last_match(1)
      extension = request_format_extension
      return :"#{variant_name}_#{extension}" if extension
    end

    nil
  end

  def request_format_extension
    format = params[:format].to_s.downcase
    %w[webp jpg].include?(format) ? format : nil
  end

  def valid_variant?(variant_key)
    Image::Variants.key?(variant_key)
  end

  def image_content_type(variant_key)
    variant_key.to_s.end_with?("jpg") ? "image/jpeg" : "image/webp"
  end
end
