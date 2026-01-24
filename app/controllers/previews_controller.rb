class PreviewsController < ApplicationController
  include PreviewRouting
  include PreviewImageServing

  skip_after_action :verify_pundit_checked

  def show
    authorize deployment_target, :show?, policy_class: PreviewPolicy

    case preview_route_type
    when :home    then render_home
    when :project then render_project
    when :post    then render_post
    when :page    then render_page
    when :image   then serve_preview_image
    else head(:not_found)
    end
  end

  private

  def deployment_target
    @deployment_target ||= DeploymentTarget.find(params[:deployment_target_id])
  end

  def site
    @site ||= deployment_target.site
  end

  def requested_path
    @requested_path ||= params[:path].to_s
  end

  def render_home
    assign_site_context(page_title: site.title, page_emoji: site.emoji, is_home: true)
    @page = site.pages.find_by(slug: "/")
    @rss_url = "/feed.xml"

    render template: "static_site/home", layout: "static_site"
  end

  def render_project
    @project = find_project_by_path
    return head(:not_found) unless @project

    assign_site_context(page_title: @project.title, page_emoji: @project.emoji)
    @header_image = @project.header_image

    render template: "static_site/project", layout: "static_site"
  end

  def render_post
    @post = find_post_by_path || find_post_by_slug
    return head(:not_found) unless @post

    assign_site_context(page_title: @post.title.presence || site.title, page_emoji: @post.emoji)
    @header_image = @post.header_image

    render template: "static_site/post", layout: "static_site"
  end

  def render_page
    @page = find_page_by_path
    return head(:not_found) unless @page

    assign_site_context(page_title: @page.title, page_emoji: @page.emoji)
    @header_image = @page.header_image

    render template: "static_site/page", layout: "static_site"
  end

  def assign_site_context(page_title:, page_emoji:, is_home: false)
    @site = site
    @page_title = page_title
    @page_emoji = page_emoji
    @is_home = is_home
    @base_url = "/preview/#{deployment_target.public_id}/"
  end
end
