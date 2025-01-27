module UserInvitations
  class Accept
    extend LightService::Organizer

    def self.call(user_invitation:)
      with(email: user_invitation.email, site: user_invitation.site, user_invitation:).reduce(
        FindOrCreateUserByEmail,
        Sites::AssociateUser,
        MarkAsAccepted,
        SendMailToInvitingUser
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

  class MarkAsAccepted
    extend LightService::Action

    expects :user_invitation

    executed do |context|
      context.user_invitation.touch(:accepted_at)
    end
  end

  class SendMailToInvitingUser
    extend LightService::Action

    expects :user_invitation

    executed do |context|
      UserInvitationMailer.invite_accepted(context.user_invitation).deliver_later
    end
  end
end
