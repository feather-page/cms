# frozen_string_literal: true

module Form
  class DatetimeFieldComponentPreview < Lookbook::Preview
    # @label Default (empty)
    def default
      render_with_template(locals: {})
    end

    # @label With Value
    def with_value
      render_with_template(locals: {})
    end

    # @label With Error
    def with_error
      render_with_template(locals: {})
    end
  end
end
