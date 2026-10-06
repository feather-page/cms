defmodule FeatherWeb.Router do
  use FeatherWeb, :router

  import FeatherWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FeatherWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # The content API (later). Authenticated with bearer API tokens.
  # scope "/api", FeatherWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:feather, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FeatherWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", FeatherWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{FeatherWeb.UserAuth, :require_authenticated}] do
      live "/", SiteLive.Index, :index
      live "/sites/new", SiteLive.New, :new
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    # Pages of one site. `SiteAuth` loads the site through
    # `Feather.Sites.get_site!/2`, so non-members get a 404.
    live_session :site,
      on_mount: [
        {FeatherWeb.UserAuth, :require_authenticated},
        {FeatherWeb.SiteAuth, :load_site}
      ] do
      live "/sites/:site_id/settings", SiteLive.Settings, :edit
      live "/sites/:site_id/users", MemberLive.Index, :index
      live "/sites/:site_id/deployments", DeploymentTargetLive.Index, :index
      live "/sites/:site_id/deployments/:id/edit", DeploymentTargetLive.Form, :edit
    end
  end

  # Invitation acceptance works logged out: the invitee may not have an
  # account yet. Accepting logs them in.
  scope "/", FeatherWeb do
    pipe_through [:browser]

    get "/invitations/:token", InvitationController, :show
    post "/invitations/:token/accept", InvitationController, :accept
  end

  scope "/", FeatherWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{FeatherWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
