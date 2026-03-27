module Hugo
  class ProjectFile < BaseFile
    attr_reader :project

    def initialize(build_path:, project:)
      super(build_path: build_path)
      @project = project
    end

    def relative_path = "content/projects/#{project.slug}.html"

    def content
      "#{JSON.pretty_generate(front_matter)}\n\n#{project.hugo_html}"
    end

    private

    def front_matter
      meta = {
        title: project.title,
        url: "/projects/#{project.slug}/",
        layout: "project",
        emoji: project.emoji,
        status: project.status,
        status_badge_class: project.status_badge_class,
        project_type: project.project_type,
        short_description: project.short_description,
        tags: project.tag_list
      }
      meta[:company] = project.company if project.company.present?
      meta[:role] = project.role if project.role.present?
      meta[:period] = project.display_period if project.respond_to?(:display_period)
      meta[:links] = project.links if project.links.present?
      if project.header_image.present?
        meta[:header_image] = header_image_data(project.header_image)
      end
      if project.thumbnail_image.present?
        meta[:thumbnail_image] = thumbnail_image_data(project.thumbnail_image)
      end
      meta
    end

    def header_image_data(image)
      {
        url: Hugo::ImageVariant.new(image: image, variant_name: :desktop_x1_webp).public_path,
        srcset: Image::Variants::SIZES.map { |name, width|
          variant = Hugo::ImageVariant.new(image: image, variant_name: :"#{name}_webp")
          "#{variant.public_path} #{width}w"
        }.join(", ")
      }
    end

    def thumbnail_image_data(image)
      {
        url: Hugo::ImageVariant.new(image: image, variant_name: :mobile_x1_webp).public_path
      }
    end
  end
end
