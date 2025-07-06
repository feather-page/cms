class DeploymentTargetPolicy < ApplicationPolicy
  def update?
    super_admin? || site_user?
  end

  def deploy?
    super_admin? || site_user?
  end

  private

  def site_user?
    super(record.site)
  end
end
