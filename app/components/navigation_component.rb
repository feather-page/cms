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
      helpers.icon('pencil'),
      helpers.edit_site_page_path(navigation.site, item.page),
      title: t('edit'), aria: { label: t('edit') },
      class: 'btn btn-sm btn-outline-secondary'
    )
  end

  def delete_link(item)
    helpers.link_to(
      helpers.icon('trash'),
      helpers.site_page_path(navigation.site, item.page),
      title: t('delete'), aria: { label: t('delete') },
      data: { turbo_method: :delete, turbo_confirm: I18n.t('are_you_sure') },
      class: 'btn btn-sm btn-outline-secondary'
    )
  end

  def remove_link(item)
    helpers.link_to(
      helpers.icon('minus'),
      helpers.navigation_item_path(item),
      title: t('navigation.remove_page'), aria: { label: t('navigation.remove_page') },
      data: { turbo_method: :delete },
      class: 'btn btn-sm btn-outline-secondary'
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
