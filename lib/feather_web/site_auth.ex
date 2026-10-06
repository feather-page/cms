defmodule FeatherWeb.SiteAuth do
  @moduledoc """
  Loads the current site for routes under `/sites/:site_id`.

  The site is looked up with `Feather.Sites.get_site!/2`, which enforces
  access: a site the user may not access raises `Ecto.NoResultsError` and
  becomes a 404, as if it did not exist. The site is put into
  `current_scope` (`Scope.put_site/2`), so contexts can trust `scope.site`.

  As a LiveView `on_mount` hook, use it after
  `{FeatherWeb.UserAuth, :require_authenticated}`:

      live_session :site,
        on_mount: [
          {FeatherWeb.UserAuth, :require_authenticated},
          {FeatherWeb.SiteAuth, :load_site}
        ] do
        live "/settings", SiteLive.Settings, :edit
      end

  Besides the scope it

    * assigns `site_preview_path`: the preview of the site's internal
      staging target, or nil,
    * subscribes to the site's notices (`Feather.Publishing.subscribe_notices/1`)
      and collects `{:site_notice, %{message: ..., url: ...}}` broadcasts
      (e.g. from the deploy pipeline) in `site_notices`, which
      `FeatherWeb.SiteComponents.site_shell/1` shows as toasts. The event
      `"dismiss_site_notice"` removes one. A LiveView that assigns
      `forward_site_notices: true` receives the notices in its own
      `handle_info/2` too,
    * swallows `{:deploy_requested, target}`, which `Feather.Publishing`
      sends to the caller instead of deploying when `:deploy_mode` is
      `:manual` (tests), so LiveViews that publish do not crash on it.

  As a plug (`plug :fetch_current_site`) it does the lookup for controllers.
  """

  use FeatherWeb, :verified_routes

  import Plug.Conn, only: [assign: 3]

  alias Feather.Accounts.Scope
  alias Feather.{Publishing, Sites}
  alias Phoenix.LiveView

  @max_notices 5

  def on_mount(:load_site, %{"site_id" => site_id}, _session, socket) do
    scope = socket.assigns.current_scope
    site = Sites.get_site!(scope, site_id)
    scope = Scope.put_site(scope, site)

    socket =
      socket
      |> Phoenix.Component.assign(:current_scope, scope)
      |> Phoenix.Component.assign(:site_preview_path, preview_path(scope))
      |> Phoenix.Component.assign(:site_notices, [])
      |> LiveView.attach_hook(:site_messages, :handle_info, &handle_message/2)
      |> LiveView.attach_hook(:dismiss_site_notice, :handle_event, &handle_dismiss/3)

    if LiveView.connected?(socket), do: Publishing.subscribe_notices(site)

    {:cont, socket}
  end

  defp handle_message({:site_notice, %{message: message} = notice}, socket) do
    notice = %{
      id: System.unique_integer([:positive]),
      message: message,
      url: Map.get(notice, :url)
    }

    notices = Enum.take([notice | socket.assigns.site_notices], @max_notices)
    socket = Phoenix.Component.assign(socket, :site_notices, notices)

    # A LiveView that wants to react to notices itself (e.g. refresh a
    # list) assigns `forward_site_notices: true` and gets them in its
    # handle_info/2 as well.
    if socket.assigns[:forward_site_notices], do: {:cont, socket}, else: {:halt, socket}
  end

  defp handle_message({:deploy_requested, _target}, socket), do: {:halt, socket}
  defp handle_message(_message, socket), do: {:cont, socket}

  defp handle_dismiss("dismiss_site_notice", %{"id" => id}, socket) do
    notices = Enum.reject(socket.assigns.site_notices, &(to_string(&1.id) == to_string(id)))
    {:halt, Phoenix.Component.assign(socket, :site_notices, notices)}
  end

  defp handle_dismiss(_event, _params, socket), do: {:cont, socket}

  defp preview_path(scope) do
    case Enum.find(Publishing.list_targets(scope), &(&1.provider == "internal")) do
      nil -> nil
      target -> ~p"/preview/#{target.public_id}"
    end
  end

  @doc """
  Plug: loads the site from the `site_id` path parameter into
  `conn.assigns.current_scope`. Raises `Ecto.NoResultsError` (404) if the
  user may not access it.
  """
  def fetch_current_site(conn, _opts) do
    scope = conn.assigns.current_scope
    site = Sites.get_site!(scope, conn.path_params["site_id"])
    assign(conn, :current_scope, Scope.put_site(scope, site))
  end
end
