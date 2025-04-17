class UserInvitationPolicy < ApplicationPolicy
  def create?
    super_admin? || site_user?(record.site)
  end

  def update?
    return false if record.accepted?
    return false if signed_in? && user.email != record.email

    true
  end

  def resend?
    return false if record.accepted?

    create?
  end

  def destroy?
    create?
  end
end
