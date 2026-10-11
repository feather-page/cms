defmodule FeatherWeb.SiteLive.Index do
  @moduledoc """
  The start page: cards of the sites the user may access (all sites for a
  super admin), each linking to the site's posts.
  """
  use FeatherWeb, :live_view

  alias Feather.Sites

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Sites
        <:subtitle>The websites you manage</:subtitle>
        <:actions>
          <.button id="new-site" variant={:primary} icon="plus" navigate={~p"/sites/new"}>
            New site
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@sites == []}
        id="no-sites"
        layout={:page}
        plush_size={:xxl}
        plush="house"
        title="No sites yet"
      >
        A site is one website: its posts, pages, books and projects.
        <:action>
          <.button navigate={~p"/sites/new"} variant={:primary} icon="plus">
            Create your first site
          </.button>
        </:action>
      </.empty_state>

      <div :if={@sites != []} id="sites" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <.card
          :for={site <- @sites}
          id={"site-#{site.public_id}"}
          title={site.title}
          subtitle={site.domain}
          navigate={~p"/sites/#{site.public_id}/posts"}
          class="transition-colors hover:border-base-content/25"
        >
          <:leading><.tile emoji={site.emoji} icon="globe" /></:leading>
        </.card>
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
