class BookshelvesController < ApplicationController
  def index
    @bookshelves = current_site.bookshelves
  end

  def new
    @bookshelf = current_site.bookshelves.new
  end

  def create
    @bookshelf = current_site.bookshelves.new(bookshelf_params)

    if @bookshelf.save
      return turbo_redirect_to(site_bookshelves_path(current_site), notice: t('.notice'))
    end
  end

  private

  def bookshelf_params
    params.expect(bookshelf: [:name])
  end
end
