module Form
  class SocialMediaPickerComponent < BaseInputComponent
    def icon_button(service)
      helpers.content_tag(
        :button,
        class: 'btn btn-outline-secondary', title: service.name,
        data: {
          icon: service.key,
          action: 'SocialMediaForm#pickService',
          'SocialMediaForm-target': 'iconButton',
          service_data: service.to_json
        }
      ) { helpers.icon(service.icon) }
    end

    def social_media_services
      @social_media_services ||= SocialMediaService.all
    end
  end
end
