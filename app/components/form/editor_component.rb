module Form
  class EditorComponent < BaseInputComponent
    def initialize(form:, attribute:)
      super
      @random_id = "block-editor-#{SecureRandom.hex(10)}"
    end

    private

    def upload_path
      helpers.site_images_path(path_params)
    end

    def from_url_path
      helpers.from_url_site_images_path(path_params)
    end

    def path_params
      params = { authenticity_token: helpers.form_authenticity_token }

      params.merge(site_id: params[:site_id])

      if @form.object.persisted?
        params[:imageable_type] = @form.object.class.name
        params[:imageable_id] = @form.object.id
      end

      params
    end
  end
end
