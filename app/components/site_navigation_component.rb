class SiteNavigationComponent < ViewComponent::Base
  attr_reader :current_site

  def initialize(current_site:)
    @current_site = current_site
  end

  def navigation_item(label, path, icon:, external: false)
    link_content = helpers.icon(icon) + "&nbsp;".html_safe + label
    link_options = { class: "nav-link" }
    link_options[:target] = "_blank" if external

    helpers.content_tag(:li, class: "nav-item") do
      helpers.link_to(link_content, path, **link_options)
    end
  end

  def preview_target
    return @preview_target if defined?(@preview_target)

    @preview_target = current_site.deployment_targets.find_by(provider: "internal")
  end
end
