# frozen_string_literal: true

class PageRowComponent < ViewComponent::Base
  def initialize(page:, site:)
    @page = page
    @site = site
  end

  def title
    @page.title
  end

  def slug
    @page.slug
  end

  def emoji
    @page.respond_to?(:emoji) ? @page.emoji.presence : nil
  end

  def page_type_badge
    @page.respond_to?(:page_type) && @page.page_type.present? && @page.page_type != "default" ? @page.page_type : nil
  end

  def edit_path
    helpers.edit_site_page_path(@site, @page)
  end

  def delete_path
    helpers.site_page_path(@site, @page)
  end

  def add_to_nav_path
    helpers.navigation_items_path(site_id: @site, page_id: @page)
  end
end
