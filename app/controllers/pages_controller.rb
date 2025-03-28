class PagesController < ApplicationController
  include Paginatable

  before_action :set_page, only: %i[edit update destroy]
  after_action :publish_current_site, only: %i[create update destroy]

  def index
    pages = current_site.pages.not_in_navigation
    @pagy, @pages = pagy(pages)
  end

  def new
    @page = current_site.pages.new
  end

  def edit; end

  def create
    @page = current_site.pages.new(page_params)
    return unless @page.save

    redirect_to_index(t('.notice'))
  end

  def update
    return unless @page.update(page_params)

    redirect_to_index(t('.notice'))
  end

  def destroy
    @page.destroy

    redirect_to_index(t('.notice'))
  end

  private

  def redirect_to_index(notice)
    turbo_redirect_to(site_pages_path(current_site), notice:)
  end

  def set_page
    @page = policy_scope(Page).find_by(public_id: params[:id])
    authorize(@page)
  end

  def page_params
    params.expect(page: %i[add_to_navigation title slug emoji content created_at])
  end
end
