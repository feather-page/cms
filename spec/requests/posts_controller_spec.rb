require "rails_helper"

describe PostsController do
  include_context "authenticated user"

  describe "GET #index" do
    it "shows all posts" do
      posts = create_list(:post, 2, site: site)
      get site_posts_path(site)
      expect(response).to be_successful
      posts.each { |p| expect(response.body).to include(p.title) }
    end
  end

  describe "POST #create" do
    context "short post (no title)" do
      it "creates a post with content only" do
        content = { blocks: [{ type: "paragraph", data: { text: "Short post text" } }] }.to_json
        expect {
          post site_posts_path(site), params: { post: { content: content } }
        }.to change(Post, :count).by(1)
      end
    end

    context "longer post with title" do
      it "creates a post with title and content" do
        content = { blocks: [{ type: "paragraph", data: { text: "Long post text" } }] }.to_json
        expect {
          post site_posts_path(site), params: { post: { title: "A long post", content: content } }
        }.to change(Post, :count).by(1)
        expect(Post.last.title).to eq("A long post")
      end
    end

    it "returns turbo stream redirect" do
      post site_posts_path(site), params: { post: { title: "Test", content: nil } }
      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "PATCH #update" do
    let(:existing_post) { create(:post, site: site) }

    it "updates the post title" do
      patch site_post_path(site, existing_post.public_id), params: { post: { title: "Updated Title" } }
      expect(existing_post.reload.title).to eq("Updated Title")
    end
  end

  describe "DELETE #destroy" do
    it "deletes the post" do
      existing_post = create(:post, site: site)
      expect {
        delete site_post_path(site, existing_post.public_id)
      }.to change(Post, :count).by(-1)
    end
  end
end
