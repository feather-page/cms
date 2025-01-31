class UserInvitationsController < ApplicationController
  def new
    @user_invitation = current_site.user_invitations.new
    authorize(@user_invitation)
  end

  def edit
    @user_invitation = current_site.user_invitations.find_by_token_for!(:accept_invitation, params[:id])
  end

  def create
    outcome = UserInvitations::Create.call(current_user:, site: current_site, email: user_invitation_params[:email])

    @user_invitation = outcome.user_invitation
    return if outcome.failure?

    turbo_redirect_to(site_users_path(current_site), notice: t('.notice'))
  end

  def update
    @user_invitation = current_site.user_invitations.find_by_token_for!(:accept_invitation, params[:id])

    result = UserInvitations::Accept.call(user_invitation: @user_invitation)
    login(result.user)

    turbo_redirect_to(root_path, notice: t('.notice'))
  end

  def destroy
    @user_invitation = UserInvitation.find(params[:id])
    authorize(@user_invitation)
    @user_invitation.destroy

    turbo_redirect_to(site_users_path(current_site), notice: t('.notice'))
  end

  def resend
    @user_invitation = UserInvitation.find(params[:id])
    authorize(@user_invitation)

    UserInvitations::Resend.call(user_invitation: @user_invitation, current_user:)

    turbo_redirect_to(site_users_path(current_site), notice: t('.notice'))
  end

  private

  def user_invitation_params
    params.expect(user_invitation: [:email])
  end
end
