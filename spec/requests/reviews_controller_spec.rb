require "rails_helper"

describe ReviewsController do
  include_context "authenticated user"

  let(:book) { create(:book, site: site) }

  describe "GET #new" do
    it "returns successful response" do
      get new_site_book_review_path(site, book)
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      { post: { title: "Great Book Review", content: nil }, rating: 5 }
    end

    it "creates a review post" do
      expect {
        post site_book_review_path(site, book), params: valid_params
      }.to change(Post, :count).by(1)
    end

    it "links the post to the book" do
      post site_book_review_path(site, book), params: valid_params
      expect(book.reload.post).to be_present
    end

    it "sets the book rating" do
      post site_book_review_path(site, book), params: valid_params
      expect(book.reload.rating).to eq(5)
    end

    it "redirects to books index" do
      post site_book_review_path(site, book), params: valid_params
      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end

    context "with invalid params" do
      it "re-renders new on failure" do
        post site_book_review_path(site, book), params: { post: { slug: "INVALID SLUG" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET #edit" do
    let(:review_post) { create(:post, site: site) }
    let(:book) { create(:book, site: site, post: review_post) }

    it "returns successful response" do
      get edit_site_book_review_path(site, book)
      expect(response).to be_successful
    end
  end

  describe "PATCH #update" do
    let(:review_post) { create(:post, site: site, title: "Original Review") }
    let(:book) { create(:book, site: site, post: review_post, rating: 3) }

    it "updates the review post" do
      patch site_book_review_path(site, book), params: { post: { title: "Updated Review" }, rating: 4 }
      expect(review_post.reload.title).to eq("Updated Review")
    end

    it "updates the book rating" do
      patch site_book_review_path(site, book), params: { post: { title: "Updated Review" }, rating: 4 }
      expect(book.reload.rating).to eq(4)
    end

    it "redirects to books index" do
      patch site_book_review_path(site, book), params: { post: { title: "Updated" }, rating: 4 }
      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "DELETE #destroy" do
    let(:review_post) { create(:post, site: site) }
    let(:book) { create(:book, site: site, post: review_post, rating: 4) }

    it "destroys the review post" do
      book # force creation
      expect {
        delete site_book_review_path(site, book)
      }.to change(Post, :count).by(-1)
    end

    it "clears the book rating" do
      delete site_book_review_path(site, book)
      expect(book.reload.rating).to be_nil
    end

    it "redirects to books index" do
      delete site_book_review_path(site, book)
      expect(response).to be_successful
      expect(response.body).to include("turbo-stream")
    end
  end
end
