module Form
  class TitleAndSlugComponent < ViewComponent::Base
    attr_reader :form, :default_title

    def initialize(form:, default_title: nil)
      @form = form
      @default_title = default_title
    end

    def slugs_path
      helpers.api_site_slugs_path(form.object.site)
    end
  end
end
