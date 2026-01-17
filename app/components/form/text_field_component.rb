module Form
  class TextFieldComponent < BaseInputComponent
    def input_classes
      classes = ['form-control']
      classes << 'is-invalid' if errors.any?
      classes.join(' ')
    end
  end
end
