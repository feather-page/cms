# frozen_string_literal: true

class SiteUserRowComponent < ViewComponent::Base
  def initialize(site_user:, site:)
    @site_user = site_user
    @site = site
  end

  def email
    @site_user.user.email
  end

  def can_destroy?
    helpers.policy(@site_user).destroy?
  end

  def delete_path
    helpers.site_user_path(@site, @site_user)
  end
end
