module StaticSite
  class ProjectCardComponent < ViewComponent::Base
    PROJECT_TYPE_LABELS = {
      "professional" => "Professional",
      "personal" => "Personal",
      "open_source" => "Open Source",
      "freelance" => "Freelance"
    }.freeze

    def initialize(project:, routes:)
      @project = project
      @routes = routes
    end

    private

    attr_reader :project, :routes

    def header_image_path
      return nil unless project.header_image&.file&.attached?

      routes.image_url(project.header_image, :mobile_x1_webp)
    end

    def thumbnail_image_path
      return nil unless project.thumbnail_image&.file&.attached?

      routes.image_url(project.thumbnail_image, :mobile_x1_webp)
    end

    def project_url
      routes.project_url(project)
    end

    def status_badge_class
      "badge-#{project.status_badge_class}"
    end

    def project_type_label
      PROJECT_TYPE_LABELS.fetch(project.project_type, project.project_type.to_s.titleize)
    end
  end
end
