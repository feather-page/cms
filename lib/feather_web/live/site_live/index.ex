defmodule FeatherWeb.SiteLive.Index do
  @moduledoc """
  The start page: cards of the sites the user may access (all sites for a
  super admin), each linking to the site's posts.
  """
  use FeatherWeb, :live_view

  alias Feather.Sites
  alias FeatherWeb.SiteAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Sites
        <:subtitle>The websites you manage</:subtitle>
        <:actions>
          <.button id="new-site" variant="primary" navigate={~p"/sites/new"}>
            <.icon name="plus" size={16} /> New site
          </.button>
        </:actions>
      </.header>

      <div :if={@sites == []} id="no-sites" class="text-center text-body-secondary py-5">
        <p class="fs-1 mb-2"><.icon name="house" size={40} /></p>
        <p>No sites yet.</p>
        <.button variant="primary" navigate={~p"/sites/new"}>Create your first site</.button>
      </div>

      <div :if={@sites != []} id="sites" class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-3">
        <div :for={site <- @sites} class="col">
          <div id={"site-#{site.public_id}"} class="card h-100">
            <div class="card-body">
              <h2 class="h5 card-title">
                <span :if={site.emoji} class="me-1">{site.emoji}</span>
                <.link href={SiteAuth.site_home_path(site)} class="stretched-link">
                  {site.title}
                </.link>
              </h2>
              <p class="card-text text-body-secondary mb-0">
                <.icon name="globe" size={16} /> {site.domain}
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sites")
     |> assign(:sites, Sites.list_sites(socket.assigns.current_scope))}
  end
end
