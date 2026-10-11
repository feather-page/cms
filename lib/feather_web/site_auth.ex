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
      and collects `{:site_notice, notice}` broadcasts (e.g. from the deploy
      pipeline) in `site_notices`, which `FeatherWeb.SiteComponents.site_shell/1`
      shows as alerts above the page content. The event
      `"dismiss_site_notice"` removes one, `"retry_deploy"` deploys the
      notice's target again and removes it,
    * assigns `site_deploy` for the deploy control of the shell: the
      production targets, how many published changes they do not show yet
      (`Feather.Publishing.undeployed_count/1`) and the progress of their
      running deploys. It is loaded on mount, again with every notice
      (a deploy ends with one), updated with every `{:deploy_progress, _}`
      and reloaded when a LiveView calls `refresh_deploy_status/1` after
      publishing in place. The event `"deploy_site"` deploys every
      production target. A LiveView that assigns
      `forward_site_notices: true` receives the notices in its own
      `handle_info/2` too, and the deploy pipeline's
      `{:deploy_progress, progress}` messages, which other LiveViews never
      see,
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
      |> Phoenix.Component.assign(:site_deploy, deploy_status(scope))
      |> LiveView.attach_hook(:site_access_on_event, :handle_event, &check_access_on_event/3)
      |> LiveView.attach_hook(:site_access_on_params, :handle_params, &check_access_on_params/3)
      |> LiveView.attach_hook(:site_messages, :handle_info, &handle_message/2)
      |> LiveView.attach_hook(:site_notice_events, :handle_event, &handle_notice_event/3)

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

  @notice_defaults %{
    kind: :info,
    title: nil,
    url: nil,
    link_label: nil,
    external: false,
    retry: nil
  }

  defp handle_message({:site_notice, %{message: _} = notice}, socket) do
    notice =
      @notice_defaults
      |> Map.merge(Map.take(notice, [:message | Map.keys(@notice_defaults)]))
      |> Map.put(:id, System.unique_integer([:positive]))

    notices = Enum.take([notice | socket.assigns.site_notices], @max_notices)

    socket =
      socket
      |> Phoenix.Component.assign(:site_notices, notices)
      |> refresh_deploy_status()

    # A LiveView that wants to react to notices itself (e.g. refresh a
    # list) assigns `forward_site_notices: true` and gets them in its
    # handle_info/2 as well.
    if socket.assigns[:forward_site_notices], do: {:cont, socket}, else: {:halt, socket}
  end

  defp handle_message({:deploy_progress, %{target_id: id} = progress}, socket) do
    socket =
      Phoenix.Component.update(socket, :site_deploy, fn deploy ->
        if Enum.any?(deploy.targets, &(&1.public_id == id)),
          do: put_in(deploy, [:progress, id], progress),
          else: deploy
      end)

    if socket.assigns[:forward_site_notices], do: {:cont, socket}, else: {:halt, socket}
  end

  defp handle_message({:deploy_requested, _target}, socket), do: {:halt, socket}

  # The picker's events are checked in the component; this also covers its
  # upload progress and any other way a change gets here.
  defp handle_message({FeatherWeb.HeaderImagePicker, _change}, socket), do: check_access(socket)
  defp handle_message(_message, socket), do: {:cont, socket}

  @doc """
  Loads the deploy status again, e.g. after publishing in place.
  """
  @spec refresh_deploy_status(LiveView.Socket.t()) :: LiveView.Socket.t()
  def refresh_deploy_status(socket) do
    Phoenix.Component.assign(socket, :site_deploy, deploy_status(socket.assigns.current_scope))
  end

  defp deploy_status(scope) do
    targets = Publishing.list_targets(scope, :production)

    %{
      targets: targets,
      pending: Publishing.undeployed_count(scope),
      progress: Publishing.deploy_progress_by_target(targets)
    }
  end

  defp handle_notice_event("dismiss_site_notice", %{"id" => id}, socket),
    do: {:halt, drop_notice(socket, id)}

  defp handle_notice_event("retry_deploy", params, socket) do
    scope = socket.assigns.current_scope

    target =
      case params do
        %{"target" => id} when is_binary(id) -> Publishing.get_target(scope, id)
        _params -> nil
      end

    socket =
      if target do
        :ok = Publishing.deploy(scope, target)
        socket
      else
        LiveView.put_flash(socket, :error, "This deployment target no longer exists.")
      end

    {:halt, drop_notice(socket, params["id"])}
  end

  defp handle_notice_event("deploy_site", _params, socket) do
    :ok = Publishing.deploy_production(socket.assigns.current_scope)
    {:halt, refresh_deploy_status(socket)}
  end

  defp handle_notice_event(_event, _params, socket), do: {:cont, socket}

  defp drop_notice(socket, id) do
    notices = Enum.reject(socket.assigns.site_notices, &(to_string(&1.id) == to_string(id)))
    Phoenix.Component.assign(socket, :site_notices, notices)
  end

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
