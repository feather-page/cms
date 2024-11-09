class SitesController < ApplicationController
  def index
    authorize(Site)
    @sites = policy_scope(Site)
  end

  def new
    authorize(Site)
    @site = Site.new
  end

  def edit
    authorize(current_site)

    @site = current_site
  end

  def create
    authorize(Site)

    outcome = Sites::CreateSite.call(
      title: site_params[:title],
      language_code: site_params[:language_code],
      domain: site_params[:domain],
      current_user:
    )
    @site = outcome.site

    turbo_redirect_to(site_posts_path(outcome.site), notice: t('.notice')) if outcome.success?
  end

  def update
    authorize(current_site)

    outcome = Sites::UpdateSite.execute(
      site: current_site,
      title: site_params[:title],
      language_code: site_params[:language_code],
      domain: site_params[:domain],
      theme_id: site_params[:theme_id]
    )

    return unless outcome.success?

    turbo_redirect_to(edit_site_path(current_site), notice: t('.notice'))
    current_site.publish
  end

  private

  def set_site
    @set_site ||= policy_scope(Site).find_by(public_id: params[:id])
  end

  def site_params
    params.require(:site).permit(:title, :language_code, :domain, :theme_id).merge(current_user:)
  end
end
