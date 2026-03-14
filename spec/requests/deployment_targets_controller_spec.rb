require "rails_helper"

describe DeploymentTargetsController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }

  before { login_as(user) }

  describe "GET #index" do
    let!(:deployment_target) { create(:deployment_target, site: site) }

    it "returns successful response" do
      get site_deployment_targets_path(site)
      expect(response).to be_successful
    end

    it "shows deployment targets for the site" do
      get site_deployment_targets_path(site)
      expect(response.body).to include(deployment_target.public_hostname)
    end

    it "does not show deployment targets from other sites" do
      other_site = create(:site)
      other_target = create(:deployment_target, site: other_site)

      get site_deployment_targets_path(site)
      expect(response.body).not_to include(other_target.public_hostname)
    end
  end

  describe "GET #edit" do
    let(:deployment_target) { create(:deployment_target, site: site) }

    it "returns successful response" do
      get edit_site_deployment_target_path(site, deployment_target)
      expect(response).to be_successful
    end
  end

  describe "PATCH #update" do
    let(:deployment_target) { create(:deployment_target, site: site) }

    context "with valid parameters" do
      it "updates the deployment target" do
        patch site_deployment_target_path(site, deployment_target),
              params: { deployment_target: { public_hostname: "new.example.com", type: deployment_target.type } }

        deployment_target.reload
        expect(deployment_target.public_hostname).to eq("new.example.com")
      end

      it "returns turbo stream redirect to deployment targets index" do
        patch site_deployment_target_path(site, deployment_target),
              params: { deployment_target: { public_hostname: "new.example.com", type: deployment_target.type } }

        expect(response).to be_successful
        expect(response.body).to include("turbo-stream")
      end

      it "sets a success notice" do
        patch site_deployment_target_path(site, deployment_target),
              params: { deployment_target: { public_hostname: "new.example.com", type: deployment_target.type } }

        expect(flash[:notice]).to be_present
      end
    end
  end

  describe "POST #deploy" do
    let(:deployment_target) { create(:deployment_target, site: site) }

    it "enqueues a StaticSite::ExportJob" do
      expect {
        post deploy_site_deployment_target_path(site, deployment_target)
      }.to have_enqueued_job(StaticSite::ExportJob)
    end

    it "returns turbo stream redirect to deployment targets index" do
      post deploy_site_deployment_target_path(site, deployment_target)

      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end

    it "sets a success notice" do
      post deploy_site_deployment_target_path(site, deployment_target)

      expect(flash[:notice]).to be_present
    end
  end
end
