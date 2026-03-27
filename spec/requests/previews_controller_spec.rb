require "rails_helper"

RSpec.describe PreviewsController do
  include_context "authenticated user"

  let(:deployment_target) { create(:deployment_target, :staging, site:) }
  let(:preview_root) { deployment_target.preview_output_path }

  before do
    allow(Hugo::BuildJob).to receive(:perform_now)
  end

  describe "GET #show" do
    context "when logged in as site user" do
      it "triggers a Hugo preview build and serves index.html" do
        FileUtils.mkdir_p(preview_root)
        File.write(preview_root.join("index.html"), "<html><body>Home Page</body></html>")

        get preview_path(deployment_target)

        expect(Hugo::BuildJob).to have_received(:perform_now).with(deployment_target, preview: true)
        expect(response).to be_successful
        expect(response.body).to include("Home Page")
      end

      it "serves a nested path from the preview directory" do
        nested_dir = preview_root.join("posts", "hello-world")
        FileUtils.mkdir_p(nested_dir)
        File.write(nested_dir.join("index.html"), "<html><body>Hello World Post</body></html>")

        get preview_path(deployment_target, path: "posts/hello-world")

        expect(response).to be_successful
        expect(response.body).to include("Hello World Post")
      end

      it "serves a file directly by its full path" do
        FileUtils.mkdir_p(preview_root.join("css"))
        File.write(preview_root.join("css", "style.css"), "body { color: red; }")

        get preview_path(deployment_target, path: "css/style.css")

        expect(response).to be_successful
        expect(response.content_type).to include("text/css")
        expect(response.body).to include("body { color: red; }")
      end

      it "returns 404 for a missing file" do
        FileUtils.mkdir_p(preview_root)

        get preview_path(deployment_target, path: "nonexistent")

        expect(response).to have_http_status(:not_found)
      end

      it "prevents path traversal outside the preview root" do
        FileUtils.mkdir_p(preview_root)

        get preview_path(deployment_target, path: "../../etc/passwd")

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when logged in as unrelated user" do
      let(:other_user) { create(:user) }

      before { login_as(other_user) }

      it "returns not found" do
        get preview_path(deployment_target)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not logged in" do
      before { login_as(nil) }

      it "redirects to login" do
        get preview_path(deployment_target)

        expect(response).to redirect_to(login_path)
      end
    end
  end
end
