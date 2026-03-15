# frozen_string_literal: true

class PageHeaderComponent < ViewComponent::Base
  def initialize(title:, breadcrumb_items: nil)
    @title = title
    @breadcrumb_items = breadcrumb_items
  end
end
