# frozen_string_literal: true

class NavigationItemRowComponent < ViewComponent::Base
  def initialize(item:, site:)
    @item = item
    @site = site
  end

  delegate :page, to: :@item

  def title
    page.title
  end

  def slug
    page.slug
  end

  def emoji
    page.emoji.presence
  end

  def first?
    @item.first?
  end

  def last?
    @item.last?
  end

  def edit_path
    helpers.edit_site_page_path(@site, page)
  end

  def move_up_path
    helpers.move_up_navigation_item_path(@item)
  end

  def move_down_path
    helpers.move_down_navigation_item_path(@item)
  end

  def remove_path
    helpers.navigation_item_path(@item)
  end
end
