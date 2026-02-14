# frozen_string_literal: true

describe Hugo::ProjectFile do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site: site) }
  let(:project) do
    create(:project, site: site, title: "My Project", slug: "my-project",
                     status: :completed, company: "Acme", role: "Developer")
  end

  subject(:project_file) { described_class.new(project, deployment_target) }

  describe "#relative_path" do
    it "returns the content path based on slug" do
      expect(project_file.relative_path).to eq("content/projects/my-project.html")
    end
  end

  describe "#content" do
    it "includes front matter with project data" do
      data = JSON.parse(project_file.content.lines.first)

      expect(data["title"]).to eq("My Project")
      expect(data["url"]).to eq("/projects/my-project/")
      expect(data["layout"]).to eq("project")
      expect(data["status"]).to eq("completed")
      expect(data["company"]).to eq("Acme")
      expect(data["role"]).to eq("Developer")
    end

    it "includes short_description" do
      data = JSON.parse(project_file.content.lines.first)

      expect(data["short_description"]).to eq(project.short_description)
    end

    it "includes period" do
      data = JSON.parse(project_file.content.lines.first)

      expect(data["period"]).to eq(project.display_period)
    end

    context "with a header image" do
      let(:image) { create(:image, site: site) }

      before { project.update!(header_image: image) }

      it "includes header image data" do
        data = JSON.parse(project_file.content.lines.first)

        expect(data["header_image"]["url"]).to include(image.public_id)
      end
    end
  end
end
