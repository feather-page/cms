class PreviewPolicy < ApplicationPolicy
  def show?
    super_admin? || site_user?(record.site)
  end
end
