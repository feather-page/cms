# frozen_string_literal: true

class ButtonComponentPreview < Lookbook::Preview
  # @label Primary
  def primary
    render ButtonComponent.new(variant: :primary, label: "Primary Button")
  end

  # @label Secondary
  def secondary
    render ButtonComponent.new(variant: :secondary, label: "Secondary Button")
  end

  # @label Danger
  def danger
    render ButtonComponent.new(variant: :danger, label: "Delete")
  end

  # @label Ghost
  def ghost
    render ButtonComponent.new(variant: :ghost, label: "Ghost Button")
  end

  # @label Small
  def small
    render ButtonComponent.new(variant: :primary, size: :sm, label: "Small")
  end

  # @label With Icon
  def with_icon
    render ButtonComponent.new(variant: :primary, label: "Add Item", icon: "file-plus")
  end

  # @label As Link
  def as_link
    render ButtonComponent.new(variant: :primary, label: "Visit Page", href: "#")
  end
end
