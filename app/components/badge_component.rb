# frozen_string_literal: true

class BadgeComponent < ViewComponent::Base
  VARIANTS = %i[neutral accent success danger].freeze

  def initialize(label:, variant: :neutral)
    @label = label
    @variant = VARIANTS.include?(variant) ? variant : :neutral
  end

  def call
    content_tag(:span, @label, class: "badge badge--#{@variant}")
  end
end
