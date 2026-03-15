# frozen_string_literal: true

class AlertComponent < ViewComponent::Base
  VARIANTS = %i[info success danger].freeze

  def initialize(variant: :info, dismissible: false)
    @variant = VARIANTS.include?(variant) ? variant : :info
    @dismissible = dismissible
  end

  def dismissible?
    @dismissible
  end
end
