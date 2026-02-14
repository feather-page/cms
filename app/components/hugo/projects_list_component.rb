# frozen_string_literal: true

module Hugo
  class ProjectsListComponent < ViewComponent::Base
    PROJECT_TYPE_LABELS = {
      "professional" => "Professional",
      "personal" => "Personal",
      "open_source" => "Open Source",
      "freelance" => "Freelance",
    }.freeze

    def initialize(projects:)
      @projects = sort_projects(projects)
    end

    private

    def sort_projects(projects)
      ongoing, other = projects.partition { |p| p.status == "ongoing" }
      ongoing_sorted = ongoing.sort_by(&:started_at).reverse
      other_sorted = other.sort_by { |p| p.ended_at || p.started_at }.reverse
      ongoing_sorted + other_sorted
    end

    def project_url(project)
      slug = project.slug.sub(%r{^/}, "")
      "/projects/#{slug}/"
    end

    def status_badge_class(project)
      "badge-#{project.status_badge_class}"
    end

    def project_type_label(project)
      PROJECT_TYPE_LABELS.fetch(project.project_type, project.project_type.to_s.titleize)
    end
  end
end
