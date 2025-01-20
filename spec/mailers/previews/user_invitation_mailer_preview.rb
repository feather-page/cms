class UserInvitationMailerPreview < ActionMailer::Preview
  def invite
    UserInvitationMailer.invite(
      UserInvitation.new(
        email: 'luigi@example.com',
        site: Site.new(title: 'Super Mario Bros')
      )
    )
  end
end
