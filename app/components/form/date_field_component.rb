module Form
  class DateFieldComponent < BaseInputComponent
    def value
      date = form.object.send(attribute) || placeholder

      return unless date

      l(date, format: :html_datetime)
    end
  end
end
