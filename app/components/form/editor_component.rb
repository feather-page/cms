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

    def editor_json
      Blocks.to_editor_js(@form.object.blocks)
    end

    def from_url_path
      helpers.from_url_site_images_path(path_params)
    end

    def link_search_path
      helpers.api_site_links_path(site_id:)
    end

    def path_params
      params = { authenticity_token: helpers.form_authenticity_token }
      params[:site_id] = site_id

      if @form.object.persisted?
        params[:imageable_type] = @form.object.class.name
        params[:imageable_id] = @form.object.id
      end

      params
    end

    def site_id
      helpers.params[:site_id] || @form.object.site&.public_id
    end
  end
end
