class UserInvitationsController < ApplicationController
  def index
    @user_invitations = current_site.user_invitations
  end

  def new
    @user_invitation = current_site.user_invitations.new
    authorize(@user_invitation)
  end

  def create
    InviteUser.execute(current_user:, site: current_site, email: user_invitation_params[:email])

    turbo_redirect_to(site_user_invitations_path(current_site), notice: t('.notice'))
  end

  def user_invitation_params
    params.require(:user_invitation).permit(:email)
  end
end
