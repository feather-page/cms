module Sites
  class UpdateSite
    extend LightService::Action

    expects :copyright, :emoji, :site, :title, :language_code, :domain

    executed do |context|
      context.site.assign_attributes(
        context.slice(:copyright, :emoji, :title, :language_code, :domain)
      )

      context.fail_and_return!(context.site.errors.full_messages.join(", ")) unless context.site.save
    end
  end
end
