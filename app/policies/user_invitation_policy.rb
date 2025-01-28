class UserInvitationPolicy < ApplicationPolicy
  def create?
    super_admin? || site_user?(record.site)
  end

  def resend?
    create?
  end

  def destroy?
    create?
  end
end
