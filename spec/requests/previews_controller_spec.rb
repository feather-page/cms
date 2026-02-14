# frozen_string_literal: true

describe PreviewsController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }

  describe "GET #show" do
    context "when logged in as site user" do
      before { login_as(user) }

      context "with built Hugo output" do
        before do
          FileUtils.mkdir_p(deployment_target.source_dir)
        end

        after do
          FileUtils.rm_rf(deployment_target.build_path)
        end

        describe "home page" do
          before do
            File.write(File.join(deployment_target.source_dir, "index.html"), "<html><body>#{site.title}</body></html>")
          end

          it "serves the home page for root path" do
            get preview_root_path(deployment_target)

            expect(response).to be_successful
            expect(response.content_type).to include("text/html")
          end

          it "serves the home page for index.html" do
            get preview_path(deployment_target, path: "index.html")

            expect(response).to be_successful
          end
        end

        describe "post pages" do
          before do
            FileUtils.mkdir_p(File.join(deployment_target.source_dir, "posts/test-post"))
            File.write(
              File.join(deployment_target.source_dir, "posts/test-post/index.html"),
              "<html><body>My Post</body></html>"
            )
          end

          it "serves a post page" do
            get preview_path(deployment_target, path: "posts/test-post/")

            expect(response).to be_successful
          end

          it "returns 404 for non-existent post" do
            get preview_path(deployment_target, path: "posts/nonexistent/")

            expect(response).to have_http_status(:not_found)
          end
        end

        describe "pages" do
          before do
            FileUtils.mkdir_p(File.join(deployment_target.source_dir, "about"))
            File.write(
              File.join(deployment_target.source_dir, "about/index.html"),
              "<html><body>About Me</body></html>"
            )
          end

          it "serves a page" do
            get preview_path(deployment_target, path: "about")

            expect(response).to be_successful
          end
        end

        describe "images" do
          before do
            FileUtils.mkdir_p(File.join(deployment_target.source_dir, "images/abc123"))
            File.write(
              File.join(deployment_target.source_dir, "images/abc123/desktop_x1.webp"),
              "fake-webp-data"
            )
          end

          it "serves an image" do
            get preview_path(deployment_target, path: "images/abc123/desktop_x1.webp")

            expect(response).to be_successful
            expect(response.content_type).to include("image/webp")
          end

          it "returns 404 for non-existent image" do
            get preview_path(deployment_target, path: "images/nonexistent/desktop_x1.webp")

            expect(response).to have_http_status(:not_found)
          end
        end

        describe "CSS files" do
          before do
            File.write(File.join(deployment_target.source_dir, "styles.css"), "body { color: red; }")
          end

          it "serves CSS with correct content type" do
            get preview_path(deployment_target, path: "styles.css")

            expect(response).to be_successful
            expect(response.content_type).to include("text/css")
          end
        end

        describe "path traversal protection" do
          it "returns 404 for path traversal attempts" do
            get preview_path(deployment_target, path: "../../../etc/passwd")

            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context "without built Hugo output" do
        it "returns 404 when no build exists" do
          get preview_root_path(deployment_target)

          expect(response).to have_http_status(:not_found)
        end
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
