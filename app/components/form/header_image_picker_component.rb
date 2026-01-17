module Form
  class HeaderImagePickerComponent < BaseInputComponent
    def initialize(form:, attribute: :header_image_id)
      super(form:, attribute:, data: {})
      @form = form
    end

    def current_image
      @form.object.header_image
    end

    def search_url
      helpers.search_site_unsplash_images_path(site)
    end

    def create_url
      helpers.site_unsplash_images_path(site)
    end

    def upload_url
      helpers.site_images_path(site)
    end

    def site
      @form.object.site
    end
  end
end
