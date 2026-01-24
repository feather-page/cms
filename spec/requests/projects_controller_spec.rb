require "rails_helper"

describe ProjectsController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }

  describe "GET #index" do
    let!(:old_project) { create(:project, site: site, title: "Old Project", started_at: 2.years.ago) }
    let!(:new_project) { create(:project, site: site, title: "New Project", started_at: 1.year.ago) }

    it "returns successful response" do
      get site_projects_path(site)
      expect(response).to be_successful
    end

    it "shows projects ordered by started_at desc" do
      get site_projects_path(site)
      expect(response.body).to include("New Project")
      expect(response.body).to include("Old Project")
    end

    it "does not show projects from other sites" do
      other_site = create(:site)
      create(:project, site: other_site, title: "Other Site Project")

      get site_projects_path(site)
      expect(response.body).not_to include("Other Site Project")
    end
  end

  describe "GET #new" do
    it "returns successful response" do
      get new_site_project_path(site)
      expect(response).to be_successful
    end

    it "renders new project form" do
      get new_site_project_path(site)
      expect(response.body).to include('New Project')
    end
  end

  describe "GET #edit" do
    let(:project) { create(:project, site: site) }

    it "returns successful response" do
      get edit_site_project_path(site, project)
      expect(response).to be_successful
    end

    it "renders edit project form" do
      get edit_site_project_path(site, project)
      expect(response.body).to include('Edit Project')
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        project: {
          title: "New Project",
          slug: "new-project",
          short_description: "A test project",
          started_at: Date.current,
          status: "ongoing",
          project_type: "professional"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new project" do
        expect do
          post site_projects_path(site), params: valid_params
        end.to change(Project, :count).by(1)
      end

      it "assigns the project to the current site" do
        post site_projects_path(site), params: valid_params
        expect(Project.last.site).to eq(site)
      end

      it "returns turbo stream redirect to projects index" do
        post site_projects_path(site), params: valid_params
        expect(response).to be_successful
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('/projects')
      end

      it "sets a success notice" do
        post site_projects_path(site), params: valid_params
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          project: {
            title: "", # Required field
            slug: "test-slug"
          }
        }
      end

      it "does not create a project" do
        expect do
          post site_projects_path(site), params: invalid_params
        end.not_to change(Project, :count)
      end

      it "renders the new template" do
        post site_projects_path(site), params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH #update" do
    let(:project) { create(:project, site: site) }
    let(:valid_params) do
      {
        project: {
          title: "Updated Project",
          short_description: "Updated description"
        }
      }
    end

    context "with valid parameters" do
      it "updates the project" do
        patch site_project_path(site, project), params: valid_params
        project.reload
        expect(project.title).to eq("Updated Project")
        expect(project.short_description).to eq("Updated description")
      end

      it "returns turbo stream redirect to projects index" do
        patch site_project_path(site, project), params: valid_params
        expect(response).to be_successful
        expect(response.body).to include('turbo-stream')
        expect(response.body).to include('/projects')
      end

      it "sets a success notice" do
        patch site_project_path(site, project), params: valid_params
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          project: {
            title: "" # Required field
          }
        }
      end

      it "does not update the project" do
        original_title = project.title
        patch site_project_path(site, project), params: invalid_params
        project.reload
        expect(project.title).to eq(original_title)
      end

      it "renders the edit template" do
        patch site_project_path(site, project), params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:project) { create(:project, site: site) }

    it "deletes the project" do
      expect do
        delete site_project_path(site, project)
      end.to change(Project, :count).by(-1)
    end

    it "returns successful response" do
      delete site_project_path(site, project)
      expect(response).to be_successful
    end
  end

  describe "authorization" do
    let(:other_site) { create(:site) }
    let(:project) { create(:project, site: other_site) }

    it "does not allow editing projects from other sites" do
      expect do
        get edit_site_project_path(site, project)
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "links parameter handling" do
    let(:project_params) do
      {
        project: {
          title: "Project with Links",
          slug: "project-with-links",
          short_description: "A project with links",
          started_at: Date.current,
          status: "ongoing",
          project_type: "professional",
          links: [
            { "label" => "Website", "url" => "https://example.com" },
            { "label" => "GitHub", "url" => "https://github.com/example" }
          ]
        }
      }
    end

    it "accepts links parameter as array" do
      post site_projects_path(site), params: project_params
      project = Project.last
      expect(project.links).to eq([
                                    { "label" => "Website", "url" => "https://example.com" },
                                    { "label" => "GitHub", "url" => "https://github.com/example" }
                                  ])
    end
  end
end
