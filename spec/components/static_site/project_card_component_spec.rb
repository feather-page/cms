describe StaticSite::ProjectCardComponent, type: :component do
  let(:site) { create(:site) }
  let(:project) do
    create(:project, site: site, title: "Test Project", company: "Test Company",
                     started_at: Date.new(2024, 1, 1), ended_at: Date.new(2024, 6, 1),
                     status: :completed, project_type: :professional, role: "Lead Developer",
                     short_description: "A test project for component testing.", emoji: "🚀")
  end

  describe "#initialize" do
    it "accepts project parameter" do
      component = described_class.new(project: project)
      expect(component).to be_a(described_class)
    end
  end

  describe "private methods" do
    describe "#project_url" do
      it "returns the correct project URL" do
        test_project = create(:project, site: site, slug: "my-test-project")
        component = described_class.new(project: test_project)
        rendered = render_inline(component)
        expect(rendered.css(".project-title").first["href"]).to eq("/projects/my-test-project/")
      end
    end

    describe "#status_badge_class" do
      it "returns badge-success for completed status" do
        completed_project = create(:project, site: site, status: :completed)
        component = described_class.new(project: completed_project)
        rendered = render_inline(component)
        expect(rendered.css(".badge-success")).to be_present
      end

      it "returns badge-primary for ongoing status" do
        ongoing_project = create(:project, site: site, status: :ongoing)
        component = described_class.new(project: ongoing_project)
        rendered = render_inline(component)
        expect(rendered.css(".badge-primary")).to be_present
      end

      it "returns badge-warning for paused status" do
        paused_project = create(:project, site: site, status: :paused)
        component = described_class.new(project: paused_project)
        rendered = render_inline(component)
        expect(rendered.css(".badge-warning")).to be_present
      end

      it "returns badge-secondary for abandoned status" do
        abandoned_project = create(:project, site: site, status: :abandoned)
        component = described_class.new(project: abandoned_project)
        rendered = render_inline(component)
        expect(rendered.css(".badge-secondary")).to be_present
      end
    end

    describe "#project_type_label" do
      it "returns 'Professional' for professional type" do
        professional_project = create(:project, site: site, project_type: :professional)
        component = described_class.new(project: professional_project)
        rendered = render_inline(component)
        expect(rendered.text).to include("Professional")
      end

      it "returns 'Personal' for personal type" do
        personal_project = create(:project, site: site, project_type: :personal)
        component = described_class.new(project: personal_project)
        rendered = render_inline(component)
        expect(rendered.text).to include("Personal")
      end

      it "returns 'Open Source' for open_source type" do
        os_project = create(:project, site: site, project_type: :open_source)
        component = described_class.new(project: os_project)
        rendered = render_inline(component)
        expect(rendered.text).to include("Open Source")
      end

      it "returns 'Freelance' for freelance type" do
        freelance_project = create(:project, site: site, project_type: :freelance)
        component = described_class.new(project: freelance_project)
        rendered = render_inline(component)
        expect(rendered.text).to include("Freelance")
      end
    end
  end

  describe "rendering" do
    it "renders all project information" do
      component = described_class.new(project: project)
      rendered = render_inline(component)

      expect(rendered.text).to include("Test Project")
      expect(rendered.text).to include("Test Company")
      expect(rendered.text).to include("Lead Developer")
      expect(rendered.text).to include("A test project for component testing.")
      expect(rendered.css(".project-emoji").text).to eq("🚀")
    end

    it "displays project period" do
      component = described_class.new(project: project)
      rendered = render_inline(component)

      expect(rendered.text).to include(project.display_period)
    end

    it "links to project detail page" do
      component = described_class.new(project: project)
      rendered = render_inline(component)

      link = rendered.css(".project-title").first
      expect(link).to be_present
      expect(link["href"]).to include("/projects/#{project.slug}/")
    end

    it "displays status and type badges" do
      component = described_class.new(project: project)
      rendered = render_inline(component)

      badges = rendered.css(".badge")
      expect(badges.map(&:text)).to include("Completed")
      expect(badges.map(&:text)).to include("Professional")
    end

    it "displays full description" do
      long_description = "A" * 200
      project.update!(short_description: long_description)
      component = described_class.new(project: project)
      rendered = render_inline(component)

      description_text = rendered.css(".project-description").text
      expect(description_text).to eq(long_description)
    end

    context "when optional fields are missing" do
      let(:minimal_project) do
        create(:project, site: site, title: "Minimal Project", company: nil, role: nil,
                         short_description: "A minimal project", emoji: nil)
      end

      it "still renders the title" do
        component = described_class.new(project: minimal_project)
        rendered = render_inline(component)

        expect(rendered.text).to include("Minimal Project")
      end

      it "does not render empty company" do
        component = described_class.new(project: minimal_project)
        rendered = render_inline(component)

        expect(rendered.css(".project-company")).to be_empty
      end

      it "does not render empty role" do
        component = described_class.new(project: minimal_project)
        rendered = render_inline(component)

        expect(rendered.css(".project-role")).to be_empty
      end

      it "renders the provided description" do
        component = described_class.new(project: minimal_project)
        rendered = render_inline(component)

        expect(rendered.css(".project-description").text).to include("A minimal project")
      end

      it "does not render empty emoji" do
        component = described_class.new(project: minimal_project)
        rendered = render_inline(component)

        expect(rendered.css(".project-emoji")).to be_empty
      end
    end
  end
end
