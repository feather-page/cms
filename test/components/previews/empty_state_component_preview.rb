# frozen_string_literal: true

class EmptyStateComponentPreview < Lookbook::Preview
  # @label Default
  def default
    render EmptyStateComponent.new(icon: "files", message: "No documents found.")
  end

  # @label With Action
  def with_action
    render EmptyStateComponent.new(
      icon: "file-plus",
      message: "You haven't created any posts yet.",
      action_label: "Create Post",
      action_href: "#"
    )
  end
end
