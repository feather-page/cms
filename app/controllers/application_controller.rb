class ApplicationController < ActionController::Base
  layout -> { turbo_frame_request? ? false : "application" }

  include Pundit::Authorization

  before_action :authenticate!

  before_action :set_site
  after_action :verify_pundit_checked

  helper_method :current_user
  helper_method :current_site

  def current_site
    set_site
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  private

  def publish_current_site
    current_site.publish
  end

  def set_site
    return @set_site if defined?(@set_site)

    return unless params[:site_id]

    @set_site = policy_scope(Site).find_by(public_id: params[:site_id])
    authorize(@set_site, :show?)
  end

  def verify_pundit_checked
    return if pundit_policy_authorized?
    return if pundit_policy_scoped?

    raise Pundit::AuthorizationNotPerformedError, self.class
  end

  def authenticate!
    current_user || redirect_to(login_path)
  end

  def login(user)
    user.touch(:last_login_at)
    session[:user_id] = user.id
  end

  def logout
    session[:user_id] = nil
  end

  def render_json(template)
    render template, formats: [:json], handlers: [:jbuilder], layout: false
  end

  def turbo_redirect_to(location, *_args, **flashes)
    if flashes.any?
      flashes.each do |type, message|
        # rubocop:disable Rails/ActionControllerFlashBeforeRender
        flash[type] = message
        # rubocop:enable Rails/ActionControllerFlashBeforeRender
      end
    end
    render turbo_stream: render_to_string(partial: 'system/turbo_redirect', locals: { location: })
  end
end
