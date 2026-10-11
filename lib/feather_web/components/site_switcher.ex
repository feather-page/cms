defmodule FeatherWeb.SiteSwitcher do
  @moduledoc """
  The site switcher below the brand of `FeatherWeb.SiteComponents.site_shell/1`:
  setzkasten's dropdown showing the current site, listing the user's sites
  (the current one marked) and linking to the site list.

  A LiveComponent, so the shell can show the user's sites without every
  LiveView under `/sites/:site_id` loading them.

      <.live_component module={FeatherWeb.SiteSwitcher} id="site-switcher" scope={@current_scope} />
  """
  use Phoenix.LiveComponent
  use FeatherWeb, :verified_routes
  use Setzkasten

  alias Feather.Sites

  @impl true
  def update(%{scope: scope} = assigns, socket) do
    {:ok,
     socket
     |> assign(:id, assigns.id)
     |> assign(:site, scope.site)
     |> assign(:sites, Sites.list_sites(scope))}
  end

  # A LiveComponent needs a static tag at its root, so the dropdown sits in a div.
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-0">
      <.dropdown
        id={@id}
        label={"Site: #{@site.title}"}
        variant={:ghost}
        class="min-w-0"
        trigger_class="max-w-full flex-nowrap px-2 sm:max-w-72"
      >
        <:trigger>
          <span aria-hidden="true">{@site.emoji}</span>
          <span class="truncate" id={"#{@id}-title"}>{@site.title}</span>
        </:trigger>
        <:header>Switch site</:header>
        <:item
          :for={site <- @sites}
          navigate={~p"/sites/#{site.public_id}/posts"}
          active={site.id == @site.id}
        >
          <span aria-hidden="true">{site.emoji}</span>
          <span class="min-w-0 flex-1 truncate">{site.title}</span>
        </:item>
        <:item navigate={~p"/"} icon="building-2" divider>All sites</:item>
      </.dropdown>
    </div>
    """
  end
end
