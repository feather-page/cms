class SiteNavigationComponent < ViewComponent::Base
  attr_reader :current_site

  def initialize(current_site:)
    @current_site = current_site
  end

  def navigation_item(label, path, icon:)
    link_content = helpers.icon(icon) + "&nbsp;".html_safe + label
    helpers.link_to(link_content, path, class: "navbar-item")
  end
end
