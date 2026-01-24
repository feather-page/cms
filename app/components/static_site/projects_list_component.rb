module StaticSite
  class ProjectsListComponent < ViewComponent::Base
    def initialize(projects:, base_url: "/")
      @projects = sort_projects(projects)
      @base_url = base_url
    end

    attr_reader :base_url

    private

    def sort_projects(projects)
      ongoing, other = projects.partition { |p| p.status == "ongoing" }
      ongoing_sorted = ongoing.sort_by(&:started_at).reverse
      other_sorted = other.sort_by { |p| p.ended_at || p.started_at }.reverse
      ongoing_sorted + other_sorted
    end
  end
end
