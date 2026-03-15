# frozen_string_literal: true

module Form
  class SocialMediaPickerComponentPreview < Lookbook::Preview
    # @label Default
    def default
      render_with_template(locals: {})
    end

    # @label With Selected Service
    def with_selected_service
      render_with_template(locals: {})
    end
  end
end
