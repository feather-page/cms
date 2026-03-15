# frozen_string_literal: true

class ProjectListItemComponentPreview < Lookbook::Preview
  # @label Project
  def default
    site = Site.first
    project = site&.projects&.first
    render ProjectListItemComponent.new(project: project, site: site) if project
  end
end
