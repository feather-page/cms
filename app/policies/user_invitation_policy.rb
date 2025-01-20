class UserInvitationPolicy < ApplicationPolicy
  def create?
    super_admin? || site_user?(record.site)
  end
end
