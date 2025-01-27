module UserInvitations
  class Accept
    extend LightService::Organizer

    def self.call(user_invitation:)
      with(email: user_invitation.email, site: user_invitation.site).reduce(
        FindOrCreateUserByEmail,
        Sites::AssociateUser
      )
    end
  end

  class FindOrCreateUserByEmail
    extend LightService::Action

    expects :email
    promises :user

    executed do |context|
      context.user = User.find_or_create_by!(email: context.email)
    end
  end
end
