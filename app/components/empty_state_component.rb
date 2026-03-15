# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  def initialize(icon:, message:, action_label: nil, action_href: nil)
    @icon = icon
    @message = message
    @action_label = action_label
    @action_href = action_href
  end

  def render_action?
    @action_label.present? && @action_href.present?
  end
end
