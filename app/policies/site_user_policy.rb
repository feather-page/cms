class SiteUserPolicy < ApplicationPolicy
  class Scope < Scope
    attr_reader :user, :scope

    def resolve
      return SiteUser.none unless @user
      return scope.all if @user.super_admin?

      scope.where(site_id: @user.site_ids)
    end
  end
end
