# frozen_string_literal: true

module Form
  # @label Editor (Rich Text)
  class EditorComponentPreview < Lookbook::Preview
    # Renders the EditorJS-powered rich text editor shell.
    # Full functionality (image uploads, book lookups) requires a real site
    # context and is not available in this preview.
    #
    # @label Default
    def default
      render_with_template(locals: {})
    end
  end
end
