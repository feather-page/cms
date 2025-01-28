class SiteUsersController < ApplicationController
  def index
    @users = policy_scope(current_site.site_users)
    @user_invitations = current_site.user_invitations.pending
  end
end
