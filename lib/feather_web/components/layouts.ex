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
  Renders the app layout: top navigation (sites, the user's email,
  settings, log out) and the main container.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <nav class="app-nav border-bottom mb-4">
      <div class="container d-flex align-items-center gap-3 py-2">
        <.link navigate={~p"/"} class="app-brand text-decoration-none fw-bold">
          🪶 Feather
        </.link>
        <ul
          :if={@current_scope && @current_scope.user}
          class="nav nav-pills ms-auto align-items-center"
        >
          <li class="nav-item">
            <.link navigate={~p"/"} class="nav-link">
              <.icon name="houses" size={16} /> Sites
            </.link>
          </li>
          <li class="nav-item">
            <span class="nav-link text-body-secondary" id="current-user-email">
              <.icon name="user" size={16} /> {@current_scope.user.email}
            </span>
          </li>
          <li class="nav-item">
            <.link navigate={~p"/users/settings"} class="nav-link">
              <.icon name="settings" size={16} /> Settings
            </.link>
          </li>
          <li class="nav-item">
            <.link href={~p"/users/log-out"} method="delete" class="nav-link">
              <.icon name="log-out" size={16} /> Log out
            </.link>
          </li>
        </ul>
        <ul :if={!(@current_scope && @current_scope.user)} class="nav nav-pills ms-auto">
          <li class="nav-item">
            <.link navigate={~p"/users/log-in"} class="nav-link">Log in</.link>
          </li>
        </ul>
      </div>
    </nav>

    <main class="container pb-5">
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
