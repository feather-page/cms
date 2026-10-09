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

    * checks access again before every event and every `handle_params/3`
      (one `exists?` query; super admins pass): a member removed while
      the LiveView is open is redirected to the site list with an error
      instead of acting on the site. Events of LiveComponents skip the
      LiveView's hooks: a component that acts on the site calls
      `check_component_events/1` on mount (and `check_access/1` where it
      acts outside events, e.g. on upload progress). The changes the
      `FeatherWeb.HeaderImagePicker` sends its LiveView are checked too,
    * assigns `site_preview_path`: the preview of the site's internal
      staging target, or nil,
    * subscribes to the site's notices (`Feather.Publishing.subscribe_notices/1`)
      and collects `{:site_notice, %{message: ..., url: ...}}` broadcasts
      (e.g. from the deploy pipeline) in `site_notices`, which
      `FeatherWeb.SiteComponents.site_shell/1` shows as toasts. The event
      `"dismiss_site_notice"` removes one. Besides those, `site_notices`
      holds a warning linking to the deployment targets while published
      changes are not deployed to production
      (`Feather.Publishing.undeployed_changes?/1`), checked on mount,
      again with every notice, since a deploy ends with one, and when a
      LiveView calls `refresh_undeployed_notice/1` after publishing in
      place. A LiveView that assigns
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
      |> Phoenix.Component.assign(:site_notices, put_undeployed_notice([], scope))
      |> LiveView.attach_hook(:site_access_on_event, :handle_event, &check_access_on_event/3)
      |> LiveView.attach_hook(:site_access_on_params, :handle_params, &check_access_on_params/3)
      |> LiveView.attach_hook(:site_messages, :handle_info, &handle_message/2)
      |> LiveView.attach_hook(:dismiss_site_notice, :handle_event, &handle_dismiss/3)

    if LiveView.connected?(socket), do: Publishing.subscribe_notices(site)

    {:cont, socket}
  end

  defp check_access_on_event(_event, _params, socket), do: check_access(socket)
  defp check_access_on_params(_params, _uri, socket), do: check_access(socket)

  @doc """
  For the `mount/1` of a LiveComponent rendered under a site route (it
  needs `current_scope` with the site): checks access before each of its
  events, like the LiveView's own.
  """
  @spec check_component_events(LiveView.Socket.t()) :: LiveView.Socket.t()
  def check_component_events(socket),
    do:
      LiveView.attach_hook(socket, :site_access_on_event, :handle_event, &check_access_on_event/3)

  @doc """
  Checks that the scope's user may still access the site: `{:cont,
  socket}`, or `{:halt, socket}` redirected to the site list with an
  error. Membership can be revoked while a LiveView is open; mount only
  checked it once.
  """
  @spec check_access(LiveView.Socket.t()) :: {:cont | :halt, LiveView.Socket.t()}
  def check_access(socket) do
    %Scope{site: site} = scope = socket.assigns.current_scope

    if Sites.can_access_site?(scope, site) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> LiveView.put_flash(:error, "You no longer have access to this site.")
       |> LiveView.redirect(to: ~p"/")}
    end
  end

  defp handle_message({:site_notice, %{message: message} = notice}, socket) do
    notice = %{
      id: System.unique_integer([:positive]),
      kind: :info,
      message: message,
      url: Map.get(notice, :url),
      link_label: nil
    }

    notices =
      [notice | socket.assigns.site_notices]
      |> Enum.take(@max_notices)
      |> put_undeployed_notice(socket.assigns.current_scope)

    socket = Phoenix.Component.assign(socket, :site_notices, notices)

    # A LiveView that wants to react to notices itself (e.g. refresh a
    # list) assigns `forward_site_notices: true` and gets them in its
    # handle_info/2 as well.
    if socket.assigns[:forward_site_notices], do: {:cont, socket}, else: {:halt, socket}
  end

  defp handle_message({:deploy_requested, _target}, socket), do: {:halt, socket}

  # The picker's events are checked in the component; this also covers its
  # upload progress and any other way a change gets here.
  defp handle_message({FeatherWeb.HeaderImagePicker, _change}, socket), do: check_access(socket)
  defp handle_message(_message, socket), do: {:cont, socket}

  @undeployed_notice_id "undeployed-changes"

  @doc """
  Checks again whether published changes are not deployed yet and shows
  or removes the notice, e.g. after publishing without a navigation.
  """
  @spec refresh_undeployed_notice(LiveView.Socket.t()) :: LiveView.Socket.t()
  def refresh_undeployed_notice(socket) do
    %{site_notices: notices, current_scope: scope} = socket.assigns
    Phoenix.Component.assign(socket, :site_notices, put_undeployed_notice(notices, scope))
  end

  defp put_undeployed_notice(notices, %Scope{site: site} = scope) do
    notices = Enum.reject(notices, &(&1.id == @undeployed_notice_id))

    if Publishing.undeployed_changes?(scope) do
      notices ++
        [
          %{
            id: @undeployed_notice_id,
            kind: :warning,
            message: "Published changes are not deployed yet.",
            url: ~p"/sites/#{site.public_id}/deployments",
            link_label: "Deployment targets"
          }
        ]
    else
      notices
    end
  end

  defp handle_dismiss("dismiss_site_notice", %{"id" => id}, socket) do
    notices = Enum.reject(socket.assigns.site_notices, &(to_string(&1.id) == to_string(id)))
    {:halt, Phoenix.Component.assign(socket, :site_notices, notices)}
  end

  defp handle_dismiss(_event, _params, socket), do: {:cont, socket}

  defp preview_path(scope) do
    case Publishing.preview_target_public_id(scope) do
      nil -> nil
      public_id -> ~p"/preview/#{public_id}"
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
