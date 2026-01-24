describe StaticSite::ProjectsListComponent, type: :component do
  let(:site) { create(:site) }
  let(:old_project) do
    create(:project, site: site, title: "Legacy System Migration", company: "TechCorp",
                     started_at: Date.new(2020, 1, 1), ended_at: Date.new(2020, 12, 1), status: :completed,
                     short_description: "Migrated legacy system to modern architecture.")
  end
  let(:recent_project) do
    create(:project, site: site, title: "New API Development", company: "StartupCo",
                     started_at: Date.new(2024, 6, 1), status: :ongoing,
                     short_description: "Building RESTful API for mobile app.")
  end
  let(:projects) { [old_project, recent_project] }

  describe "#initialize" do
    it "accepts projects parameter" do
      component = described_class.new(projects: projects)
      expect(component).to be_a(described_class)
    end
  end

  describe "private methods" do
    describe "#sort_projects" do
      it "places ongoing projects first" do
        component = described_class.new(projects: projects)
        rendered = render_inline(component)
        project_titles = rendered.css(".project-title").map(&:text)
        expect(project_titles.first).to eq("New API Development")
        expect(project_titles.last).to eq("Legacy System Migration")
      end

      it "sorts ongoing projects by started_at descending" do
        older_ongoing = create(:project, site: site, title: "Older Ongoing",
                                         started_at: Date.new(2023, 1, 1), status: :ongoing)
        newer_ongoing = create(:project, site: site, title: "Newer Ongoing",
                                         started_at: Date.new(2024, 1, 1), status: :ongoing)
        component = described_class.new(projects: [older_ongoing, newer_ongoing])
        rendered = render_inline(component)
        project_titles = rendered.css(".project-title").map(&:text)
        expect(project_titles.first).to eq("Newer Ongoing")
        expect(project_titles.last).to eq("Older Ongoing")
      end

      it "sorts completed projects by ended_at descending" do
        older_completed = create(:project, site: site, title: "Older Completed",
                                           started_at: Date.new(2020, 1, 1),
                                           ended_at: Date.new(2020, 6, 1), status: :completed)
        newer_completed = create(:project, site: site, title: "Newer Completed",
                                           started_at: Date.new(2021, 1, 1),
                                           ended_at: Date.new(2021, 12, 1), status: :completed)
        component = described_class.new(projects: [older_completed, newer_completed])
        rendered = render_inline(component)
        project_titles = rendered.css(".project-title").map(&:text)
        expect(project_titles.first).to eq("Newer Completed")
        expect(project_titles.last).to eq("Older Completed")
      end
    end

    describe "#project_url" do
      it "returns the correct project URL" do
        project = create(:project, site: site, slug: "test-project", started_at: Date.new(2024, 1, 1))
        component = described_class.new(projects: [project])
        rendered = render_inline(component)
        expect(rendered.css(".project-title").first["href"]).to eq("/projects/test-project/")
      end
    end

    describe "#status_badge_class" do
      it "returns correct badge class for completed status" do
        component = described_class.new(projects: [old_project])
        rendered = render_inline(component)
        expect(rendered.css(".badge-success")).to be_present
      end

      it "returns correct badge class for ongoing status" do
        component = described_class.new(projects: [recent_project])
        rendered = render_inline(component)
        expect(rendered.css(".badge-primary")).to be_present
      end
    end

    describe "#project_type_label" do
      let(:personal_project) do
        create(:project, site: site, project_type: :personal, started_at: Date.new(2024, 1, 1))
      end

      it "returns correct label for professional type" do
        professional_project = create(:project, site: site, project_type: :professional,
                                                started_at: Date.new(2024, 1, 1))
        component = described_class.new(projects: [professional_project])
        rendered = render_inline(component)
        expect(rendered.text).to include("Professional")
      end

      it "returns correct label for personal type" do
        component = described_class.new(projects: [personal_project])
        rendered = render_inline(component)
        expect(rendered.text).to include("Personal")
      end
    end
  end

  describe "rendering" do
    it "renders project information" do
      component = described_class.new(projects: [recent_project])
      rendered = render_inline(component)

      expect(rendered.text).to include("New API Development")
      expect(rendered.text).to include("StartupCo")
      expect(rendered.text).to include("Building RESTful API for mobile app.")
    end

    it "displays emoji when present" do
      recent_project.update!(emoji: "🚀")
      component = described_class.new(projects: [recent_project])
      rendered = render_inline(component)

      expect(rendered.css(".project-emoji").text).to eq("🚀")
    end

    it "displays project period" do
      component = described_class.new(projects: [recent_project])
      rendered = render_inline(component)

      expect(rendered.text).to include(recent_project.display_period)
    end

    it "displays status badge" do
      component = described_class.new(projects: [recent_project])
      rendered = render_inline(component)

      expect(rendered.css(".badge").text).to include("Ongoing")
    end

    it "displays full description" do
      long_description = "A" * 200
      recent_project.update!(short_description: long_description)
      component = described_class.new(projects: [recent_project])
      rendered = render_inline(component)

      description_text = rendered.css(".project-description").text
      expect(description_text).to eq(long_description)
    end

    it "renders a flat list without year headers" do
      component = described_class.new(projects: projects)
      rendered = render_inline(component)
      expect(rendered.css("h2")).to be_empty
    end
  end
end
