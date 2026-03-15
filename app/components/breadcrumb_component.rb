# frozen_string_literal: true

class BreadcrumbComponent < ViewComponent::Base
  def initialize(items:)
    @items = items
  end
end
