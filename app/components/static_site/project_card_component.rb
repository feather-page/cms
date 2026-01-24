module StaticSite
  class ProjectCardComponent < ViewComponent::Base
    PROJECT_TYPE_LABELS = {
      "professional" => "Professional",
      "personal" => "Personal",
      "open_source" => "Open Source",
      "freelance" => "Freelance"
    }.freeze

    def initialize(project:, base_url: "/")
      @project = project
      @base_url = base_url
    end

    private

    attr_reader :project, :base_url

    def header_image_path
      return nil unless project.header_image&.file&.attached?

      "/images/#{project.header_image.public_id}/mobile_x1.webp"
    end

    def project_url
      slug = project.slug.sub(%r{^/}, "")
      "#{base_url}projects/#{slug}/"
    end

    def status_badge_class
      "badge-#{project.status_badge_class}"
    end

    def project_type_label
      PROJECT_TYPE_LABELS.fetch(project.project_type, project.project_type.to_s.titleize)
    end
  end
end
