class UserInvitationMailer < ApplicationMailer
  def invite(user_invitation)
    @user_invitation = user_invitation

    subject = t('user_invitation_mailer.invite.subject', site_name: @user_invitation.site.title)
    @token = user_invitation.generate_token_for(:accept_invitation)
    mail to: user_invitation.email, subject:
  end

  def invite_accepted(user_invitation)
    @user_invitation = user_invitation

    subject =
      t('user_invitation_mailer.invite_accepted.subject',
        email: @user_invitation.email,
        site_name: @user_invitation.site.title)
    mail to: user_invitation.inviting_user.email, subject: subject
  end
end
