# frozen_string_literal: true

module Form
  class CheckboxComponentPreview < Lookbook::Preview
    # @label Unchecked
    def default
      render_with_template(locals: {})
    end

    # @label Checked
    def checked
      render_with_template(locals: {})
    end
  end
end
