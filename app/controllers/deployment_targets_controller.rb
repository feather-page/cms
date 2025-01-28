class DeploymentTargetsController < ApplicationController
  before_action :set_deployment_target, only: %i[edit update]

  def index
    @deployment_targets = current_site.deployment_targets
  end

  def edit
    authorize(@deployment_target)
  end

  def update
    authorize(@deployment_target)

    result = DeploymentTargets::UpdateDeploymentTarget.execute(
      deployment_target: @deployment_target,
      public_hostname: deployment_target_params[:public_hostname],
      type: deployment_target_params[:type]
    )

    return unless result.success?

    turbo_redirect_to(
      site_deployment_targets_path(@deployment_target.site),
      notice: t('.notice')
    )
  end

  private

  def deployment_target_params
    params.expect(deployment_target: %i[public_hostname type]).merge(current_user:)
  end

  def set_deployment_target
    @deployment_target = current_site.deployment_targets.find_by!(public_id: params[:id])
  end
end
