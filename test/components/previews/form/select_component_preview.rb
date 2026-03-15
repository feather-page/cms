# frozen_string_literal: true

module Form
  class SelectComponentPreview < Lookbook::Preview
    # @label Default
    def default
      render_with_template(locals: {})
    end

    # @label With Selected Value
    def with_selected_value
      render_with_template(locals: {})
    end

    # @label With Error
    def with_error
      render_with_template(locals: {})
    end
  end
end
