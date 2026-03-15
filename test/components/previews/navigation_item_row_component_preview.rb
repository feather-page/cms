# frozen_string_literal: true

class NavigationItemRowComponentPreview < Lookbook::Preview
  # @label Navigation Item
  def default
    site = Site.first
    item = site&.main_navigation&.navigation_items&.ordered&.first
    render NavigationItemRowComponent.new(item: item, site: site) if item
  end
end
