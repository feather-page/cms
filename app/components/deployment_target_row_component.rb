# frozen_string_literal: true

class DeploymentTargetRowComponent < ViewComponent::Base
  def initialize(target:, site:)
    @target = target
    @site = site
  end

  def hostname
    @target.public_hostname
  end

  def type_label
    I18n.t("deployment_target.types.#{@target.type}")
  end

  def icon_class
    @target.type == "production" ? "deployment-row__icon--production" : "deployment-row__icon--staging"
  end

  def deploy_path
    helpers.deploy_site_deployment_target_path(@site, @target)
  end

  def edit_path
    helpers.edit_site_deployment_target_path(@site, @target)
  end

  def preview_path
    helpers.preview_path(@target)
  end

  def show_preview?
    @target.provider == "internal"
  end
end
