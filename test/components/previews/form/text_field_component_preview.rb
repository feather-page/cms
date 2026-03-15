# frozen_string_literal: true

module Form
  class TextFieldComponentPreview < Lookbook::Preview
    # @label Default
    def default
      render_with_template(locals: { value: nil, errors: {} })
    end

    # @label With Value
    def with_value
      render_with_template(locals: { value: "Hello World", errors: {} })
    end

    # @label With Error
    def with_error
      render_with_template(locals: { value: "bad value", errors: { title: ["can't be blank"] } })
    end

    # @label With Placeholder
    def with_placeholder
      render_with_template(locals: { value: nil, errors: {}, placeholder: "Enter a title…" })
    end
  end
end
