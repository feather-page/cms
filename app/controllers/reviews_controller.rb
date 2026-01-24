class ReviewsController < ApplicationController
  before_action :set_book

  def new
    @post = @book.site.posts.new
  end

  def edit
    @post = @book.post
  end

  def create
    @post = @book.site.posts.new(post_params)

    if @post.save
      @book.update(post: @post, rating: rating_param)
      redirect_to_books(t(".notice"))
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @post = @book.post

    if @post.update(post_params) && @book.update(rating: rating_param)
      redirect_to_books(t(".notice"))
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @book.post&.destroy
    @book.update(rating: nil)

    redirect_to_books(t(".notice"))
  end

  private

  def set_site
    @book&.site || super
  end

  def set_book
    @book = policy_scope(Book).find_by!(public_id: params[:book_id])
    authorize @book
  end

  def redirect_to_books(notice)
    turbo_redirect_to(site_books_path(@book.site), notice:)
  end

  def post_params
    params.expect(post: %i[title slug draft emoji content publish_at])
  end

  def rating_param
    params[:rating].presence&.to_i
  end
end
