class BooksController < ApplicationController
  before_action :set_book, only: %i[edit update destroy]
  after_action :publish_current_site, only: %i[create update destroy]

  def index
    @books = current_site.books.ordered
  end

  def new
    @book = current_site.books.new
  end

  def edit
    @book = set_book
  end

  def create
    @book = current_site.books.new(book_params)

    return unless @book.save

    turbo_redirect_to(site_books_path(current_site), notice: t('.notice'))
  end

  def update
    return unless @book.update(book_params)

    turbo_redirect_to(site_books_path(current_site), notice: t('.notice'))
  end

  def destroy
    @book.destroy

    render layout: false
  end

  private

  def set_site
    @book&.site || super
  end

  def set_book
    @book = policy_scope(Book).find_by(public_id: params[:id])
    authorize @book
  end

  def book_params
    params.require(:book).permit(:title, :author, :emoji, :read_at)
  end
end
