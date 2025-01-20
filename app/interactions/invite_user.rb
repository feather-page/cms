class InviteUser
  extend LightService::Action

  expects :site, :current_user, :email
  promises :user_invitation

  def self.policy_allows?(context)
    UserInvitationPolicy.new(context.current_user, context.user_invitation).create?
  end

  executed do |context|
    context.user_invitation = UserInvitation.find_or_initialize_by(
      site: context.site,
      email: context.email
    )
    context.fail! unless policy_allows?(context)

    context.user_invitation.update!(inviting_user: context.current_user)

    UserInvitationMailer.invite(context.user_invitation).deliver_later
  end
end
