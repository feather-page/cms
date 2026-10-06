defmodule FeatherWeb.SiteLive.Index do
  @moduledoc """
  Placeholder start page: lists the sites the user may access. The admin
  replaces it.
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
      </.header>

      <p :if={@sites == []} id="no-sites" class="text-body-secondary">
        You do not have any sites yet.
      </p>

      <div :if={@sites != []} id="sites" class="list-group">
        <div :for={site <- @sites} id={"site-#{site.public_id}"} class="list-group-item">
          <span class="me-2">{site.emoji}</span>
          <strong>{site.title}</strong>
          <span class="text-body-secondary ms-2">{site.domain}</span>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :sites, Sites.list_sites(socket.assigns.current_scope))}
  end
end
