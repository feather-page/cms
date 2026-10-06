defmodule FeatherWeb.SiteAuth do
  @moduledoc """
  Loads the current site for the `/sites/:site_id/...` LiveViews.

  Use it after `{FeatherWeb.UserAuth, :require_authenticated}`:

      live_session :site,
        on_mount: [
          {FeatherWeb.UserAuth, :require_authenticated},
          {FeatherWeb.SiteAuth, :load_site}
        ] do
        live "/sites/:site_id/settings", SiteLive.Settings, :edit
      end

  The site is loaded with `Feather.Sites.get_site!/2`, which enforces access:
  a site the user may not access raises `Ecto.NoResultsError` (a 404), as
  if it did not exist. The site is put into `@current_scope`.
  """

  alias Feather.Accounts.Scope
  alias Feather.Sites
  alias Feather.Sites.Site

  def on_mount(:load_site, %{"site_id" => site_id}, _session, socket) do
    scope = socket.assigns.current_scope
    site = Sites.get_site!(scope, site_id)

    {:cont, Phoenix.Component.assign(socket, :current_scope, Scope.put_site(scope, site))}
  end

  @doc """
  The start page of a site in the admin: its posts.

  Plain string until the posts LiveView is routed in this branch; switch
  to `~p"/sites/\#{site.public_id}/posts"` once it is.
  """
  @spec site_home_path(Site.t()) :: String.t()
  def site_home_path(%Site{public_id: public_id}), do: "/sites/#{public_id}/posts"
end
