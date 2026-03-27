require "rails_helper"

RSpec.describe Hugo::ProjectFile do
  let(:build_path) { Pathname.new(Dir.mktmpdir) }
  let(:site) { create(:site) }
  let(:project) do
    create(:project, site: site, title: "My Project", slug: "my-project",
           emoji: "🚀", status: :completed, project_type: :professional,
           short_description: "A test project", company: "Acme Corp",
           role: "Lead Developer", links: [{ "label" => "Site", "url" => "https://example.com" }])
  end

  subject(:file) { described_class.new(build_path: build_path, project: project) }

  after { FileUtils.rm_rf(build_path) }

  describe "#relative_path" do
    it "returns the content path based on slug" do
      expect(file.relative_path).to eq("content/projects/my-project.html")
    end
  end

  describe "#content" do
    it "contains JSON front matter followed by hugo_html" do
      content = file.content
      parts = content.split("\n\n", 2)
      expect { JSON.parse(parts.first) }.not_to raise_error
    end

    it "includes the project title" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["title"]).to eq("My Project")
    end

    it "includes the url with projects prefix" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["url"]).to eq("/projects/my-project/")
    end

    it "sets layout to project" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["layout"]).to eq("project")
    end

    it "includes emoji" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["emoji"]).to eq("🚀")
    end

    it "includes status" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["status"]).to eq("completed")
    end

    it "includes status_badge_class" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["status_badge_class"]).to eq("success")
    end

    it "includes project_type" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["project_type"]).to eq("professional")
    end

    it "includes short_description" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["short_description"]).to eq("A test project")
    end

    it "includes tags as an empty array when untagged" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["tags"]).to eq([])
    end

    it "includes company" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["company"]).to eq("Acme Corp")
    end

    it "includes role" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["role"]).to eq("Lead Developer")
    end

    it "includes period from display_period" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["period"]).to eq(project.display_period)
    end

    it "includes links" do
      front_matter = JSON.parse(file.content.split("\n\n", 2).first)
      expect(front_matter["links"]).to eq([{ "label" => "Site", "url" => "https://example.com" }])
    end

    context "with tags" do
      let(:project) do
        create(:project, :tagged, site: site, title: "Tagged Project", slug: "tagged-project",
               short_description: "Tagged", status: :completed, project_type: :professional)
      end

      it "includes tags as an array" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["tags"]).to eq(%w[ruby rails web])
      end
    end

    context "without company" do
      let(:project) do
        create(:project, :personal, site: site, title: "Personal", slug: "personal",
               short_description: "Personal project", status: :ongoing)
      end

      it "does not include company" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter).not_to have_key("company")
      end
    end

    context "without role" do
      let(:project) do
        create(:project, site: site, title: "No Role", slug: "no-role",
               short_description: "No role", role: nil, status: :completed,
               project_type: :professional)
      end

      it "does not include role" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter).not_to have_key("role")
      end
    end

    context "without links" do
      let(:project) do
        create(:project, site: site, title: "No Links", slug: "no-links",
               short_description: "No links", links: nil, status: :completed,
               project_type: :professional)
      end

      it "does not include links" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter).not_to have_key("links")
      end
    end

    context "with a header image" do
      let(:project) do
        p = create(:project, site: site, title: "With Image", slug: "with-image",
                   short_description: "Has image", status: :completed, project_type: :professional)
        p.update!(header_image: create(:image, site: site, imageable: p))
        p.reload
      end

      it "includes header_image data with url and srcset" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["header_image"]["url"]).to include("/images/")
        expect(front_matter["header_image"]["srcset"]).to include("w")
      end
    end

    context "with a thumbnail image" do
      let(:project) do
        p = create(:project, site: site, title: "With Thumb", slug: "with-thumb",
                   short_description: "Has thumbnail", status: :completed, project_type: :professional)
        p.update!(thumbnail_image: create(:image, site: site, imageable: p))
        p.reload
      end

      it "includes thumbnail_image data with url" do
        front_matter = JSON.parse(file.content.split("\n\n", 2).first)
        expect(front_matter["thumbnail_image"]["url"]).to include("/images/")
      end
    end

    it "includes hugo_html as the body" do
      allow(project).to receive(:hugo_html).and_return("<p>Project details</p>")
      parts = file.content.split("\n\n", 2)
      expect(parts.last).to eq("<p>Project details</p>")
    end
  end

  describe "#write" do
    it "writes the file to the correct path" do
      file.write
      written_path = build_path.join("content/projects/my-project.html")
      expect(written_path).to exist
    end
  end
end
