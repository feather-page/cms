# frozen_string_literal: true

class PageHeaderComponentPreview < Lookbook::Preview
  # @label Default
  def default
    render PageHeaderComponent.new(title: "All Posts")
  end

  # @label With Actions
  def with_actions
    render PageHeaderComponent.new(title: "All Posts") do
      render ButtonComponent.new(variant: :primary, label: "New Post", icon: "file-plus", size: :sm)
    end
  end
end
