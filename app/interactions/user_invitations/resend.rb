module UserInvitations
  class Resend
    extend LightService::Organizer

    def self.call(current_user:, user_invitation:)
      with(current_user:, user_invitation:).reduce(
        UpdateInvitingUser,
        SendEmail
      )
    end

    class UpdateInvitingUser
      extend LightService::Action

      expects :user_invitation, :current_user

      executed do |context|
        context.fail! unless UserInvitationPolicy.new(context.current_user, context.user_invitation).resend?
        context.user_invitation.update!(inviting_user: context.current_user)
      end
    end
  end
end
