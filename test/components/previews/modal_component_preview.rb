# frozen_string_literal: true

class ModalComponentPreview < Lookbook::Preview
  # @label With Title
  def with_title
    render ModalComponent.new(id: "example-modal", title: "Confirm Action") do
      "Are you sure you want to proceed?"
    end
  end

  # @label Without Title
  def without_title
    render ModalComponent.new(id: "simple-modal") do
      "Simple modal content."
    end
  end
end
