# frozen_string_literal: true

class PageRowComponentPreview < Lookbook::Preview
  # @label Page Row
  def default
    site = Site.first
    page = site&.pages&.first
    render PageRowComponent.new(page: page, site: site) if page
  end
end
