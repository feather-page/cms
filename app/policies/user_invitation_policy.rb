class UserInvitationPolicy < ApplicationPolicy
  def create?
    super_admin? || site_user?(record.site)
  end

  def resend?
    return false if record.accepted?

    create?
  end

  def destroy?
    create?
  end
end
