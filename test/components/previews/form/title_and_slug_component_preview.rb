# frozen_string_literal: true

module Form
  class TitleAndSlugComponentPreview < Lookbook::Preview
    # @label Default
    def default
      render_with_template(locals: {})
    end

    # @label With Existing Title and Slug
    def with_values
      render_with_template(locals: {})
    end

    # @label With Default Title
    def with_default_title
      render_with_template(locals: {})
    end
  end
end
