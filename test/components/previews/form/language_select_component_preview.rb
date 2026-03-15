# frozen_string_literal: true

module Form
  class LanguageSelectComponentPreview < Lookbook::Preview
    # @label Default
    def default
      render_with_template(locals: {})
    end

    # @label With Selected Language
    def with_selected_language
      render_with_template(locals: {})
    end

    # @label With Error
    def with_error
      render_with_template(locals: {})
    end
  end
end
