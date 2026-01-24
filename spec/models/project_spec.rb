require "rails_helper"

RSpec.describe Project do
  describe "validations" do
    context "with valid attributes" do
      it "is valid" do
        project = build(:project)
        expect(project).to be_valid
      end
    end

    context "without title" do
      it "is not valid" do
        project = build(:project, title: nil)
        expect(project).not_to be_valid
        expect(project.errors[:title]).to be_present
      end
    end

    context "without slug" do
      it "is not valid" do
        project = build(:project, slug: nil)
        expect(project).not_to be_valid
        expect(project.errors[:slug]).to be_present
      end
    end

    context "without short_description" do
      it "is not valid" do
        project = build(:project, short_description: nil)
        expect(project).not_to be_valid
        expect(project.errors[:short_description]).to be_present
      end
    end

    context "without started_at" do
      it "is not valid" do
        project = build(:project, started_at: nil)
        expect(project).not_to be_valid
        expect(project.errors[:started_at]).to be_present
      end
    end

    context "without status" do
      it "is not valid" do
        project = build(:project, status: nil)
        expect(project).not_to be_valid
        expect(project.errors[:status]).to be_present
      end
    end

    context "without project_type" do
      it "is not valid" do
        project = build(:project, project_type: nil)
        expect(project).not_to be_valid
        expect(project.errors[:project_type]).to be_present
      end
    end

    context "with duplicate slug within the same site" do
      it "is not valid" do
        site = create(:site)
        create(:project, site: site, slug: "test-project")
        duplicate_project = build(:project, site: site, slug: "test-project")

        expect(duplicate_project).not_to be_valid
        expect(duplicate_project.errors[:slug]).to be_present
      end
    end

    context "with same slug on different sites" do
      it "is valid" do
        site1 = create(:site)
        site2 = create(:site)
        create(:project, site: site1, slug: "test-project")
        duplicate_project = build(:project, site: site2, slug: "test-project")

        expect(duplicate_project).to be_valid
      end
    end
  end

  describe "status enum" do
    it "has the correct values" do
      expect(described_class.statuses).to eq({
                                               "ongoing" => 0,
                                               "completed" => 1,
                                               "paused" => 2,
                                               "abandoned" => 3
                                             })
    end

    it "generates status methods" do
      project = build(:project, status: :completed)
      expect(project).to be_completed
      expect(project).not_to be_ongoing
      expect(project).not_to be_paused
      expect(project).not_to be_abandoned
    end
  end

  describe "project_type enum" do
    it "has the correct values" do
      expect(described_class.project_types).to eq({
                                                    "professional" => 0,
                                                    "personal" => 1,
                                                    "open_source" => 2,
                                                    "freelance" => 3
                                                  })
    end

    it "generates project_type methods with prefix" do
      project = build(:project, project_type: :professional)
      expect(project).to be_project_type_professional
      expect(project).not_to be_project_type_personal
      expect(project).not_to be_project_type_open_source
      expect(project).not_to be_project_type_freelance
    end
  end

  describe "scopes" do
    describe ".ordered" do
      it "orders projects by started_at descending" do
        site = create(:site)
        old_project = create(:project, site: site, started_at: 2.years.ago)
        new_project = create(:project, site: site, started_at: 1.year.ago)

        expect(described_class.ordered).to eq([new_project, old_project])
      end
    end
  end

  describe "#display_period" do
    context "when period is present" do
      it "returns the period field" do
        project = build(:project, period: "March 2019 - August 2020")
        expect(project.display_period).to eq("March 2019 - August 2020")
      end
    end

    context "when period is blank" do
      context "with ended_at present" do
        it "returns formatted date range" do
          project = build(:project,
                          period: nil,
                          started_at: Date.new(2019, 3, 1),
                          ended_at: Date.new(2020, 8, 31))
          expect(project.display_period).to eq("March 2019 - August 2020")
        end
      end

      context "with ended_at nil (ongoing)" do
        it "returns formatted date with 'ongoing'" do
          project = build(:project,
                          period: nil,
                          started_at: Date.new(2019, 3, 1),
                          ended_at: nil)
          expect(project.display_period).to eq("March 2019 - ongoing")
        end
      end
    end
  end

  describe "associations" do
    it "belongs to site" do
      site = create(:site)
      project = create(:project, site: site)
      expect(project.site).to eq(site)
    end

    it "optionally belongs to header_image" do
      project = create(:project, header_image: nil)
      expect(project.header_image).to be_nil

      image = create(:image, site: project.site)
      project.update!(header_image: image)
      expect(project.header_image).to eq(image)
    end
  end

  describe "includes" do
    it "includes PublicIdable" do
      project = create(:project)
      expect(project.public_id).to be_present
      expect(project.public_id.length).to eq(12)
    end

    it "includes Editable" do
      project = create(:project, content: nil)
      expect(project).to respond_to(:content)
      expect(project).to respond_to(:content=)
    end
  end
end
