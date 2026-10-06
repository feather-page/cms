defmodule FeatherWeb.Router do
  use FeatherWeb, :router

  import FeatherWeb.UserAuth
  import FeatherWeb.SiteAuth, only: [fetch_current_site: 2]

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

  # Session-authenticated JSON and file endpoints of the admin (Editor.js
  # image uploads, the book block lookup, admin image files).
  pipeline :browser_json do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
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
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end
  end

  ## Site content admin
  #
  # Everything under /sites/:site_id requires a logged-in user and access to
  # the site: FeatherWeb.SiteAuth loads it with Sites.get_site!/2 (404
  # otherwise) and puts it into current_scope.

  scope "/sites/:site_id", FeatherWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :site,
      on_mount: [
        {FeatherWeb.UserAuth, :require_authenticated},
        {FeatherWeb.SiteAuth, :load_site}
      ] do
      live "/posts", PostLive.Index, :index
      live "/posts/new", PostLive.Form, :new
      live "/posts/:id/edit", PostLive.Form, :edit

      live "/pages", PageLive.Index, :index
      live "/pages/new", PageLive.Form, :new
      live "/pages/:id/edit", PageLive.Form, :edit

      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.Form, :new
      live "/projects/:id/edit", ProjectLive.Form, :edit

      live "/books", BookLive.Index, :index
      live "/books/new", BookLive.Form, :new
      live "/books/:id/edit", BookLive.Form, :edit
      live "/books/:book_id/review/new", ReviewLive.Form, :new
      live "/books/:book_id/review/edit", ReviewLive.Form, :edit
    end
  end

  scope "/sites/:site_id", FeatherWeb do
    pipe_through [:browser_json, :require_authenticated_user, :fetch_current_site]

    post "/images", ImageController, :create
    post "/images/from-url", ImageController, :from_url
    get "/images/:id", ImageController, :show
    get "/books/lookup", BookLookupController, :index
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
