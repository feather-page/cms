# frozen_string_literal: true

class AlertComponentPreview < Lookbook::Preview
  # @label Info
  def info
    render AlertComponent.new(variant: :info) do
      "This is an informational message."
    end
  end

  # @label Success
  def success
    render AlertComponent.new(variant: :success) do
      "Operation completed successfully."
    end
  end

  # @label Danger
  def danger
    render AlertComponent.new(variant: :danger) do
      "Something went wrong. Please try again."
    end
  end

  # @label Dismissible
  def dismissible
    render AlertComponent.new(variant: :info, dismissible: true) do
      "You can dismiss this alert."
    end
  end
end
