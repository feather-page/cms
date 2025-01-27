module UserInvitations
  class Create
    extend LightService::Organizer

    def self.call(current_user:, site:, email:)
      with(current_user:, site:, email:).reduce(
        FindOrInitializeByEmailAndSite,
        Invite,
        SendEmail
      )
    end
  end

  class FindOrInitializeByEmailAndSite
    extend LightService::Action

    expects :site, :email
    promises :user_invitation

    executed do |context|
      context.user_invitation = UserInvitation.find_or_initialize_by(
        site: context.site,
        email: context.email
      )
    end
  end

  class Invite
    extend LightService::Action
    expects :user_invitation, :current_user

    promises :user_invitation

    def self.policy_allows?(context)
      UserInvitationPolicy.new(context.current_user, context.user_invitation).create?
    end

    executed do |context|
      context.fail! unless policy_allows?(context)
      context.user_invitation.update!(inviting_user: context.current_user)
    end
  end
end
