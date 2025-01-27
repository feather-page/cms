module UserInvitations
  class SendEmail
    extend LightService::Action

    expects :user_invitation
    promises :user_invitation

    executed do |context|
      UserInvitationMailer.invite(context.user_invitation).deliver_later
    end
  end
end
