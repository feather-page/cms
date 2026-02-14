# frozen_string_literal: true

describe Hugo::ProjectsListComponent, type: :component do
  let(:site) { create(:site) }
  let(:ongoing_project) { create(:project, :ongoing, site: site, title: "Active Project") }
  let(:completed_project) { create(:project, site: site, title: "Done Project", status: :completed) }

  describe "rendering" do
    it "renders project titles" do
      rendered = render_inline(described_class.new(projects: [ongoing_project]))

      expect(rendered.text).to include("Active Project")
    end

    it "renders project metadata" do
      rendered = render_inline(described_class.new(projects: [ongoing_project]))

      expect(rendered.css(".project-meta")).to be_present
    end

    it "renders status badges" do
      rendered = render_inline(described_class.new(projects: [ongoing_project]))

      expect(rendered.css(".badge").text).to include("Ongoing")
    end

    it "sorts ongoing projects before completed ones" do
      rendered = render_inline(described_class.new(projects: [completed_project, ongoing_project]))

      titles = rendered.css(".project-title").map(&:text)
      expect(titles.first).to eq("Active Project")
    end

    it "renders separators between projects" do
      rendered = render_inline(described_class.new(projects: [ongoing_project, completed_project]))

      expect(rendered.css("hr").length).to eq(1)
    end

    it "renders project links" do
      rendered = render_inline(described_class.new(projects: [ongoing_project]))

      link = rendered.css(".project-title").first
      expect(link["href"]).to include("/projects/")
    end
  end
end
