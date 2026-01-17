describe PreviewsController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }

  describe "GET #show" do
    before do
      FileUtils.mkdir_p(deployment_target.source_dir)
      File.write(File.join(deployment_target.source_dir, "index.html"), "<html>Test</html>")
      File.write(File.join(deployment_target.source_dir, "page.html"), "<html>Page</html>")
    end

    after do
      FileUtils.rm_rf(deployment_target.build_path)
    end

    context "when logged in as site user" do
      before { login_as(user) }

      it "returns the index file for root path" do
        get preview_root_path(deployment_target)

        expect(response).to be_successful
        expect(response.body).to eq("<html>Test</html>")
      end

      it "returns a specific file" do
        get preview_path(deployment_target, path: "page.html")

        expect(response).to be_successful
        expect(response.body).to eq("<html>Page</html>")
      end

      it "returns index.html for directory paths" do
        FileUtils.mkdir_p(File.join(deployment_target.source_dir, "subdir"))
        File.write(File.join(deployment_target.source_dir, "subdir", "index.html"), "<html>Subdir</html>")

        get preview_path(deployment_target, path: "subdir")

        expect(response).to be_successful
        expect(response.body).to eq("<html>Subdir</html>")
      end

      it "returns 404 for non-existent file" do
        get preview_path(deployment_target, path: "nonexistent.html")

        expect(response).to have_http_status(:not_found)
      end

      it "prevents path traversal attacks" do
        get preview_path(deployment_target, path: "../../../etc/passwd")

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when logged in as unrelated user" do
      let(:other_user) { create(:user) }

      before { login_as(other_user) }

      it "denies access" do
        expect do
          get preview_root_path(deployment_target)
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when not logged in" do
      it "redirects to login" do
        get preview_root_path(deployment_target)

        expect(response).to redirect_to(login_path)
      end
    end
  end
end
