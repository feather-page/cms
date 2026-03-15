# frozen_string_literal: true

class PageLayoutComponent < ViewComponent::Base
  renders_one :actions

  def initialize(title: nil)
    @title = title
  end

  def title?
    @title.present?
  end
end
