class BooksController < ApplicationController
  before_action :set_book, only: %i[edit update destroy]
  after_action :publish_current_site, only: %i[create update destroy]

  def index
    @books = current_site.books.by_status(status_filter).ordered
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

    download_cover_if_present
    turbo_redirect_to(site_books_path(current_site), notice: t(".notice"))
  end

  def update
    return unless @book.update(book_params)

    turbo_redirect_to(site_books_path(current_site), notice: t(".notice"))
  end

  def destroy
    @book.destroy

    render layout: false
  end

  def search
    results = OpenLibrary::Client.new.search(params[:q])
    render json: results.map(&:to_h)
  end

  def lookup
    authorize current_site, :lookup?, policy_class: BookPolicy
    books = current_site.books
                        .where("title ILIKE :q OR author ILIKE :q", q: "%#{params[:q]}%")
                        .limit(10)
    render json: books.map { |b| book_lookup_json(b) }
  end

  private

  def book_lookup_json(book)
    {
      public_id: book.public_id,
      title: book.title,
      author: book.author,
      cover_url: book_cover_url(book),
      emoji: book.emoji
    }
  end

  def book_cover_url(book)
    return unless book.cover_image&.file&.attached?

    helpers.url_for(book.cover_image.file.variant(:mobile_x1_webp))
  end

  def set_site
    @book&.site || super
  end

  def set_book
    @book = policy_scope(Book).find_by(public_id: params[:id])
    authorize @book
  end

  def book_params
    params.expect(book: %i[title author emoji read_at reading_status isbn open_library_key])
  end

  def download_cover_if_present
    return if params[:cover_url].blank?

    RemoteImageCreator.new(current_site, @book).create_from(params[:cover_url])
  end

  def status_filter
    params[:status].presence || :finished
  end
end
