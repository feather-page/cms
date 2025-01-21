module Sites
  class AssociateUserWithSite
    extend LightService::Action

    expects :site, :user

    executed do |context|
      context.user.sites << context.site
    end
  end
end
