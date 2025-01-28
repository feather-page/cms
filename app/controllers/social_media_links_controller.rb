class SocialMediaLinksController < ApplicationController
  before_action :set_social_media_link, only: %i[destroy]

  def create
    authorize(current_site, :create_social_media_link?)

    @social_media_link = current_site.social_media_links.new(social_media_link_params)

    return render :new unless @social_media_link.save

    turbo_redirect_to(edit_site_path(current_site), notice: t('.success'))
    current_site.publish
  end

  def destroy
    @social_media_link.destroy
    current_site.publish
    turbo_redirect_to(edit_site_path(current_site), notice: t('.success'))
  end

  private

  def set_social_media_link
    @social_media_link = SocialMediaLink.find(params[:id])
    authorize(@social_media_link)
  end

  def social_media_link_params
    params.expect(social_media_link: %i[name url icon])
  end
end
