# frozen_string_literal: true

module Form
  # @label Header Image Picker
  class HeaderImagePickerComponentPreview < Lookbook::Preview
    # Renders the header image / emoji picker interface.
    # Image search and upload require a real site context with Unsplash API
    # credentials — those interactions are not functional in this preview.
    #
    # @label Default (no image)
    def default
      render_with_template(locals: {})
    end

    # @label With Emoji
    def with_emoji
      render_with_template(locals: {})
    end
  end
end
