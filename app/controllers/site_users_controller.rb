class SiteUsersController < ApplicationController
  def index
    @users = policy_scope(current_site.site_users)
    @user_invitations = current_site.user_invitations.pending
  end

  def destroy
    site_user = SiteUser.find(params[:id])
    authorize(site_user)
    site_user.destroy
    turbo_redirect_to(site_users_path(current_site), notice: t('.notice'))
  end
end
