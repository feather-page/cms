describe PreviewsController do
  let(:user) { create(:user) }
  let(:site) { create(:site, users: [user]) }
  let(:deployment_target) { create(:deployment_target, :staging, site:) }

  describe "GET #show" do
    context "when logged in as site user" do
      before { login_as(user) }

      describe "home page" do
        it "renders the home page for root path" do
          get preview_root_path(deployment_target)

          expect(response).to be_successful
          expect(response.body).to include(ERB::Util.html_escape(site.title))
        end

        it "renders the home page for index.html" do
          get preview_path(deployment_target, path: "index.html")

          expect(response).to be_successful
          expect(response.body).to include(ERB::Util.html_escape(site.title))
        end

        it "includes navigation items" do
          page = create(:page, site:, title: "About", slug: "/about")
          site.main_navigation.navigation_items.create!(page: page, position: 1)

          get preview_root_path(deployment_target)

          expect(response.body).to include("About")
        end

        it "lists published posts" do
          create(:post, site:, title: "Hello World", publish_at: 1.day.ago)

          get preview_root_path(deployment_target)

          expect(response.body).to include("Hello World")
        end
      end

      describe "post pages" do
        let!(:post) { create(:post, site:, title: "My Post", publish_at: 1.day.ago) }

        it "renders a post by public_id" do
          get preview_path(deployment_target, path: "posts/#{post.public_id}/")

          expect(response).to be_successful
          expect(response.body).to include("My Post")
        end

        it "renders a post by lowercase public_id" do
          get preview_path(deployment_target, path: "posts/#{post.public_id.downcase}/")

          expect(response).to be_successful
          expect(response.body).to include("My Post")
        end

        it "renders a post with custom slug" do
          post.update!(slug: "/custom-url")

          get preview_path(deployment_target, path: "custom-url")

          expect(response).to be_successful
          expect(response.body).to include("My Post")
        end

        it "renders book information for book reviews" do
          book = create(:book, site:, title: "Clean Code", author: "Robert Martin", rating: 5)
          book.update!(post:)

          get preview_path(deployment_target, path: "posts/#{post.public_id}/")

          expect(response.body).to include("Clean Code")
          expect(response.body).to include("Robert Martin")
          expect(response.body).to include("\u2605\u2605\u2605\u2605\u2605")
        end

        it "returns 404 for non-existent post" do
          get preview_path(deployment_target, path: "posts/nonexistent/")

          expect(response).to have_http_status(:not_found)
        end
      end

      describe "pages" do
        let!(:page) { create(:page, site:, title: "About Me", slug: "/about") }

        it "renders a page by slug" do
          get preview_path(deployment_target, path: "about")

          expect(response).to be_successful
          expect(response.body).to include("About Me")
        end

        it "returns 404 for non-existent page" do
          get preview_path(deployment_target, path: "nonexistent")

          expect(response).to have_http_status(:not_found)
        end
      end

      describe "images" do
        let!(:image) { create(:image, :with_file, site:) }

        it "serves an image variant" do
          get preview_path(deployment_target, path: "images/#{image.public_id}/desktop_x1.webp")

          expect(response).to be_successful
          expect(response.content_type).to eq("image/webp")
        end

        it "returns 404 for invalid variant" do
          get preview_path(deployment_target, path: "images/#{image.public_id}/invalid.webp")

          expect(response).to have_http_status(:not_found)
        end

        it "returns 404 for non-existent image" do
          get preview_path(deployment_target, path: "images/nonexistent/desktop_x1.webp")

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
