# frozen_string_literal: true

class BadgeComponentPreview < Lookbook::Preview
  # @label Neutral
  def neutral
    render BadgeComponent.new(label: "Draft", variant: :neutral)
  end

  # @label Accent
  def accent
    render BadgeComponent.new(label: "Featured", variant: :accent)
  end

  # @label Success
  def success
    render BadgeComponent.new(label: "Published", variant: :success)
  end

  # @label Danger
  def danger
    render BadgeComponent.new(label: "Error", variant: :danger)
  end
end
