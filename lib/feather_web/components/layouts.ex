defmodule FeatherWeb.Layouts do
  @moduledoc """
  The layouts of the admin.

  The root layout (`layouts/root.html.heex`) loads felt-css and the app
  assets; `app/1` renders the top navigation and the page container and is
  used explicitly by every LiveView:

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        ...
      </Layouts.app>
  """
  use FeatherWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout: the top bar (brand, user menu) and the main
  container.

  `FeatherWeb.SiteComponents.site_shell/1` fills the `leading` slot (after
  the brand) with the site switcher, the `trailing` slot (before the user
  menu) with the preview button and the `subnav` slot with the site's
  section navigation.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :leading, doc: "top bar items after the brand"
  slot :trailing, doc: "top bar items before the user menu"
  slot :subnav, doc: "navigation below the top bar, at the top of the container"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="app-topbar border-bottom">
      <div class="container d-flex align-items-center gap-2 h-100">
        <.link navigate={~p"/"} class="app-brand" aria-label="Feather, all sites">
          <span aria-hidden="true">🪶</span><span class={@leading != [] && "d-none d-sm-inline"}>Feather</span>
        </.link>
        {render_slot(@leading)}
        <div class="app-topbar__end d-flex align-items-center gap-2 ms-auto">
          {render_slot(@trailing)}
          <.dropdown
            :if={@current_scope && @current_scope.user}
            id="user-menu"
            label="Account"
            align="end"
            caret={false}
            toggle_class="btn-light btn-icon"
          >
            <:toggle><.icon name="circle-user" /></:toggle>
            <li>
              <span class="dropdown-header text-truncate" id="current-user-email">
                {@current_scope.user.email}
              </span>
            </li>
            <li>
              <.link navigate={~p"/users/settings"} class="dropdown-item" id="account-settings-link">
                <.icon name="settings" size={16} /> Account settings
              </.link>
            </li>
            <li><hr class="dropdown-divider" /></li>
            <li>
              <.link href={~p"/users/log-out"} method="delete" class="dropdown-item">
                <.icon name="log-out" size={16} /> Log out
              </.link>
            </li>
          </.dropdown>
          <.link
            :if={!(@current_scope && @current_scope.user)}
            navigate={~p"/users/log-in"}
            class="btn btn-light btn-sm"
          >
            Log in
          </.link>
        </div>
      </div>
    </header>

    <main class={["container pb-5", @subnav == [] && "pt-4"]}>
      {render_slot(@subnav)}
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="flash-group" aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="loader-circle" size={16} class="spin ms-1" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="loader-circle" size={16} class="spin ms-1" />
      </.flash>
    </div>
    """
  end
end
