# frozen_string_literal: true

class PageLayoutComponentPreview < Lookbook::Preview
  # @label With Title
  def with_title
    render PageLayoutComponent.new(title: "Dashboard") do
      "Page content goes here."
    end
  end

  # @label Without Title
  def without_title
    render PageLayoutComponent.new do
      "Page content without a header."
    end
  end
end
