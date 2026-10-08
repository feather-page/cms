defmodule FeatherWeb.SiteSwitcher do
  @moduledoc """
  The site switcher in the top bar of `FeatherWeb.SiteComponents.site_shell/1`:
  a dropdown showing the current site that lists the user's other sites
  and links to the site list.

  A LiveComponent, so the shell can show the user's sites without every
  LiveView under `/sites/:site_id` loading them.

      <.live_component module={FeatherWeb.SiteSwitcher} id="site-switcher" scope={@current_scope} />
  """
  use Phoenix.LiveComponent
  use FeatherWeb, :verified_routes

  import FeatherWeb.CoreComponents

  alias Feather.Sites

  @impl true
  def update(%{scope: scope} = assigns, socket) do
    {:ok,
     socket
     |> assign(:id, assigns.id)
     |> assign(:site, scope.site)
     |> assign(:sites, Sites.list_sites(scope))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="site-switcher">
      <.dropdown id={@id} class="mw-100" toggle_class="btn-light btn-sm site-switcher__toggle">
        <:toggle>
          <span aria-hidden="true">{@site.emoji}</span>
          <span class="text-truncate" id="site-title">{@site.title}</span>
        </:toggle>
        <li><span class="dropdown-header">Switch site</span></li>
        <li :for={site <- @sites}>
          <.link
            navigate={~p"/sites/#{site.public_id}/posts"}
            class="dropdown-item"
            aria-current={site.id == @site.id && "page"}
          >
            <span aria-hidden="true">{site.emoji}</span>
            <span class="text-truncate flex-grow-1">{site.title}</span>
            <.icon :if={site.id == @site.id} name="check" size={16} class="text-primary" />
          </.link>
        </li>
        <li><hr class="dropdown-divider" /></li>
        <li>
          <.link navigate={~p"/"} class="dropdown-item" id="all-sites-link">
            <.icon name="building-2" size={16} /> All sites
          </.link>
        </li>
      </.dropdown>
    </div>
    """
  end
end
