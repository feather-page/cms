# frozen_string_literal: true

class SiteUserRowComponentPreview < Lookbook::Preview
  # @label Site User
  def default
    site = Site.first
    site_user = site&.site_users&.first
    render SiteUserRowComponent.new(site_user: site_user, site: site) if site_user
  end
end
