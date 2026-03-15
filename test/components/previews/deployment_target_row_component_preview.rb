# frozen_string_literal: true

class DeploymentTargetRowComponentPreview < Lookbook::Preview
  # @label Deployment Target
  def default
    site = Site.first
    target = site&.deployment_targets&.first
    render DeploymentTargetRowComponent.new(target: target, site: site) if target
  end
end
