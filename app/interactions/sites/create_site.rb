module Sites
  class CreateSite
    extend LightService::Organizer

    def self.call(title:, current_user:, language_code:, domain:)
      with(title:, current_user:, language_code:, domain:, user: current_user).reduce(
        SaveSite,
        AssociateUser,
        AddHomePage,
        CreateStaging
      )
    end
  end

  class SaveSite
    extend LightService::Action

    expects :title, :language_code, :domain
    promises :site

    executed do |context|
      context.site = Site.new(
        title: context.title,
        language_code: context.language_code,
        domain: context.domain
      )
      context.fail_and_return!(context.site.errors.full_messages.to_sentence) unless context.site.save
    end
  end

  class AddHomePage
    extend LightService::Action

    expects :site

    executed do |context|
      context.site.pages.create(title: 'Home', slug: '/')
    end
  end

  class CreateStaging
    extend LightService::Action

    expects :site

    executed do |context|
      context.site.deployment_targets.create!(
        public_hostname: "#{context.site.public_id}.stage.#{ENV.fetch('BASE_HOSTNAME_AND_PORT')}",
        type: :staging, provider: :internal
      )
    end
  end
end
