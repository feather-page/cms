module StaticSite
  class ProjectsListComponent < ViewComponent::Base
    def initialize(projects:, routes: nil)
      @projects = sort_projects(projects)
      @routes = routes
    end

    attr_reader :routes

    private

    def sort_projects(projects)
      ongoing, other = projects.partition { |p| p.status == "ongoing" }
      ongoing_sorted = ongoing.sort_by(&:started_at).reverse
      other_sorted = other.sort_by { |p| p.ended_at || p.started_at }.reverse
      ongoing_sorted + other_sorted
    end
  end
end
