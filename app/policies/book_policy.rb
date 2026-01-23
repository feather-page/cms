class BookPolicy < ApplicationPolicy
  class Scope < Scope
    attr_reader :user, :scope

    def resolve
      return scope.all if @user.super_admin?

      scope.joins(site: :site_users).where(site_users: { user: })
    end
  end

  %i[edit? update? destroy? new? create?].each do |action|
    define_method(action) do
      super_admin? || site_user?(record.site)
    end
  end

  def lookup?
    super_admin? || site_user?(record)
  end
end
