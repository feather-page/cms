class UserInvitationMailerPreview < ActionMailer::Preview
  def invite
    UserInvitationMailer.invite(
      UserInvitation.new(
        email: 'luigi@example.com',
        site: Site.new(title: 'Super Mario Bros')
      )
    )
  end

  def invite_accepted
    UserInvitationMailer.invite_accepted(
      UserInvitation.new(
        email: 'luigi@example.com',
        site: Site.new(title: 'Super Mario Bros'),
        inviting_user: User.new(email: 'inviter@example.com')
      )
    )
  end
end
