class NavigationComponent < ViewComponent::Base
  attr_reader :navigation

  delegate :navigation_items, to: :navigation

  def initialize(navigation:)
    @navigation = navigation
  end

  def item_title(item)
    item.page.title
  end

  def item_path(item)
    item.page.slug
  end

  def edit_link(item)
    helpers.link_to(
      t('edit'),
      helpers.edit_site_page_path(navigation.site, item.page),
      class: 'btn btn-sm btn-outline-secondary'
    )
  end

  def delete_link(item)
    helpers.link_to(
      t('delete'),
      helpers.site_page_path(navigation.site, item.page),
      data: { turbo_method: :delete },
      class: 'btn btn-sm btn-outline-secondary'
    )
  end

  def remove_link(item)
    helpers.link_to(
      t('navigation.remove_page'),
      helpers.navigation_item_path(item),
      data: { turbo_method: :delete }, class: 'btn btn-sm btn-outline-secondary'
    )
  end

  def up_link(item)
    return inactive_button('caret-up-square') if item.first?

    helpers.link_to(
      helpers.icon('caret-up-square'),
      helpers.move_up_navigation_item_path(item),
      title: t('navigation.move_up'),
      data: { turbo_method: :patch }, class: 'btn btn-sm btn-outline-secondary'
    )
  end

  def down_link(item)
    return inactive_button('caret-down-square') if item.last?

    helpers.link_to(
      helpers.icon('caret-down-square'),
      helpers.move_down_navigation_item_path(item),
      title: t('navigation.move_down'),
      data: { turbo_method: :patch }, class: 'btn btn-sm btn-outline-secondary'
    )
  end

  private

  def inactive_button(icon)
    helpers.content_tag(:span, helpers.icon(icon), class: 'btn btn-sm btn-outline-secondary disabled')
  end
end
