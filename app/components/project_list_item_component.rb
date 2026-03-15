# frozen_string_literal: true

class ProjectListItemComponent < ViewComponent::Base
  def initialize(project:, site:)
    @project = project
    @site = site
  end

  def icon_content
    if @project.emoji.present?
      content_tag(:span, @project.emoji, class: "list-row__emoji")
    else
      helpers.icon("rocket")
    end
  end

  def edit_path
    helpers.edit_site_project_path(@site, @project)
  end

  def delete_path
    helpers.site_project_path(@site, @project)
  end

  def status_variant
    @project.respond_to?(:status_badge_variant) ? @project.status_badge_variant : :neutral
  end
end
