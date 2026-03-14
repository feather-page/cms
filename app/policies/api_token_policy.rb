class ApiTokenPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.all if @user&.super_admin?

      scope.where(user: @user)
    end
  end

  def create?
    signed_in?
  end

  def destroy?
    super_admin? || record.user_id == user.id
  end
end
