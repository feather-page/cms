class PreviewsController < ApplicationController
  include PreviewImageServing

  skip_after_action :verify_pundit_checked

  def show
    authorize deployment_target, :show?, policy_class: PreviewPolicy

    case routes.resolve(requested_path)
    in { kind: :home, params: { page: } }               then render_home(page)
    in { kind: :project, record: }                      then render_project(record)
    in { kind: :post, record: }                         then render_post(record)
    in { kind: :page, record: }                         then render_page(record)
    in { kind: :image, record:, params: { variant: } }  then serve_preview_image(record, variant)
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

  def routes
    @routes ||= StaticSite::Routes.for(deployment_target, as: :preview)
  end

  def requested_path
    @requested_path ||= begin
      path = params[:path].to_s
      # Rails parses a trailing .webp/.jpg out of a glob path into params[:format];
      # restore it so Routes#resolve sees the full address.
      format = params[:format]
      format.in?(%w[webp jpg]) ? "#{path}.#{format}" : path
    end
  end

  def render_home(page_number)
    assign_site_context(page_title: site.title, page_emoji: site.emoji, is_home: true)
    @page = site.pages.find_by(slug: "/")
    @rss_url = "/feed.xml"

    all_posts = site.posts.published.order(publish_at: :desc)
    per_page = StaticSite::ExportJob::POSTS_PER_PAGE
    @current_page = page_number
    @total_pages = [(all_posts.count / per_page.to_f).ceil, 1].max
    @posts = all_posts.offset((@current_page - 1) * per_page).limit(per_page)

    render template: "static_site/home", layout: "static_site"
  end

  def render_project(project)
    @project = project
    assign_site_context(page_title: @project.title, page_emoji: @project.emoji)
    @header_image = @project.header_image

    render template: "static_site/project", layout: "static_site"
  end

  def render_post(post)
    @post = post
    assign_site_context(page_title: @post.title.presence || site.title, page_emoji: @post.emoji)
    @header_image = @post.header_image

    render template: "static_site/post", layout: "static_site"
  end

  def render_page(page)
    @page = page
    assign_site_context(page_title: @page.title, page_emoji: @page.emoji)
    @header_image = @page.header_image

    render template: "static_site/page", layout: "static_site"
  end

  def assign_site_context(page_title:, page_emoji:, is_home: false)
    @site = site
    @page_title = page_title
    @page_emoji = page_emoji
    @is_home = is_home
    @base_url = routes.site_root
  end
end
