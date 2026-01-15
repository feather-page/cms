module Form
  class BaseInputComponent < ViewComponent::Base
    attr_reader :form, :attribute, :data, :placeholder

    def initialize(form:, attribute:, placeholder: nil, data: {})
      @form = form
      @attribute = attribute
      @placeholder = placeholder
      @data = data
    end

    protected

    def errors
      form.object.errors[attribute]
    end

    def help_text
      help_texts = []
      help_texts << helpers.tag.div(errors.join(', '), class: 'invalid-feedback') if errors.any?

      help_texts << helpers.tag.div(translation_for_help_text, class: 'form-text') if translation_for_help_text.present?

      # rubocop:disable Rails/OutputSafety
      # This is safe because we are using the Rails tag helper
      help_texts.join.html_safe
      # rubocop:enable Rails/OutputSafety
    end

    def translation_for_help_text
      return unless form.object.respond_to?(:model_name)

      translation_key_for_help_text = "activerecord.help.#{form.object.model_name.i18n_key}.#{attribute}.html"

      return unless I18n.exists?(translation_key_for_help_text)

      helpers.t(translation_key_for_help_text)
    end

    def input_classes
      classes = ['form-control']
      classes << 'is-invalid' if errors.any?
      classes.join(' ')
    end
  end
end
