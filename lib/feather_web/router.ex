defmodule FeatherWeb.Router do
  use FeatherWeb, :router

  import FeatherWeb.UserAuth
  import FeatherWeb.SiteAuth, only: [fetch_current_site: 2]

  # Content-Security-Policy of the admin (and the preview, which renders on
  # the same origin): scripts only from our own origin, so markup that slips
  # into a page (inline handlers, inline scripts) does not run. Styles and
  # fonts also come from felt-css; Editor.js injects inline styles. Images
  # (Unsplash, Open Library covers) and the embeds of the editor may come
  # from any https origin.
  @csp_directives [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline' https://felt-css.rocu.de",
    "font-src 'self' data: https://felt-css.rocu.de",
    "img-src 'self' data: blob: https:",
    "connect-src 'self'",
    "frame-src 'self' https:",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'self'"
  ]

  @browser_headers %{"content-security-policy" => Enum.join(@csp_directives, "; ")}

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FeatherWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @browser_headers
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
    plug :put_secure_browser_headers, @browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api_token do
    plug FeatherWeb.Plugs.ApiAuth
  end

  # kamal-proxy's health check (config/deploy.yml). No pipeline: no
  # session, no CSRF; excluded from force_ssl in config/prod.exs.
  scope "/", FeatherWeb do
    get "/up", HealthController, :show
  end

  # Caddy's on-demand TLS check (ops/Caddyfile). Unauthenticated and
  # outside the :api pipeline: Caddy sends no Accept header we could rely on.
  scope "/api", FeatherWeb.Api do
    get "/caddy/check_domain", CaddyController, :check_domain
  end

  # The content API, see docs/api/openapi.yml. Authenticated with bearer
  # API tokens (`mix feather.api_token`); the token's user must have access
  # to the site.
  scope "/api/v1/sites/:site_id", FeatherWeb.Api.V1 do
    pipe_through [:api, :api_token]

    resources "/posts", PostController, except: [:new, :edit]
    resources "/pages", PageController, except: [:new, :edit]
    resources "/images", ImageController, only: [:show, :create]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:feather, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    # The dashboard and the mailbox preview use inline scripts: no CSP here.
    pipeline :dev_tools do
      plug :delete_content_security_policy
    end

    scope "/dev" do
      pipe_through [:browser, :dev_tools]

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
  end

  # Invitation acceptance works logged out: the invitee may not have an
  # account yet. Accepting logs them in.
  scope "/", FeatherWeb do
    pipe_through [:browser]

    get "/invitations/:token", InvitationController, :show
    post "/invitations/:token/accept", InvitationController, :accept
  end

  # The preview of a site's static pages: logged-in users with access to
  # the target's site (checked in the controller).
  scope "/preview", FeatherWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/:target_id", PreviewController, :show
    get "/:target_id/*path", PreviewController, :show
  end

  ## Site content admin
  #
  # Everything under /sites/:site_id (content, settings, users,
  # deployments) requires a logged-in user and access to the site:
  # FeatherWeb.SiteAuth loads it with Sites.get_site!/2 (404 otherwise) and
  # puts it into current_scope.

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

      live "/settings", SiteLive.Settings, :edit
      live "/users", MemberLive.Index, :index
      live "/deployments", DeploymentTargetLive.Index, :index
      live "/deployments/:id/edit", DeploymentTargetLive.Form, :edit
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

  if Application.compile_env(:feather, :dev_routes) do
    defp delete_content_security_policy(conn, _opts),
      do: Plug.Conn.delete_resp_header(conn, "content-security-policy")
  end
end
