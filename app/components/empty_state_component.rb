# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  def initialize(icon: nil, emoji: nil, message:, subtitle: nil, action_label: nil, action_href: nil)
    @icon = icon
    @emoji = emoji
    @message = message
    @subtitle = subtitle
    @action_label = action_label
    @action_href = action_href
  end

  def render_action?
    @action_label.present? && @action_href.present?
  end

  def emoji_mode?
    @emoji.present?
  end
end
