defmodule FeatherWeb.PageLive.Index do
  @moduledoc """
  The pages of a site: the pages in the main navigation (ordered, move
  up/down, remove) and the other pages (20 per page, add to navigation).
  Every navigation change publishes the site, like Rails'
  `NavigationItemsController` did.
  """
  use FeatherWeb, :live_view

  alias Feather.{Content, Publishing, Sites}

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      preview_path={@site_preview_path}
      active={:pages}
    >
      <.header>
        Pages
        <:actions>
          <.button variant="primary" navigate={~p"/sites/#{@site.public_id}/pages/new"} id="new-page">
            <.icon name="plus" size={16} /> New page
          </.button>
        </:actions>
      </.header>

      <section class="list-section">
        <h2 class="section-title">
          In navigation <span class="section-title__count">{length(@navigation_items)}</span>
        </h2>
        <p :if={@navigation_items == []} id="no-navigation-items" class="text-body-secondary">
          No pages in the navigation yet.
        </p>
        <.list_card id="navigation-items" hidden={@navigation_items == []}>
          <.list_row
            :for={{item, index} <- Enum.with_index(@navigation_items)}
            id={"navigation-item-#{item.page.public_id}"}
            navigate={edit_path(@site, item.page)}
          >
            <:leading><.page_tile page={item.page} /></:leading>
            {item.page.title}
            <:meta><.page_meta page={item.page} /></:meta>
            <:action
              id={"move-up-#{item.page.public_id}"}
              icon="chevron-up"
              label="Move up"
              click={JS.push("move_up", value: %{id: item.page.public_id})}
              hidden={index == 0}
            />
            <:action
              id={"move-down-#{item.page.public_id}"}
              icon="chevron-down"
              label="Move down"
              click={JS.push("move_down", value: %{id: item.page.public_id})}
              hidden={index == length(@navigation_items) - 1}
            />
            <:action
              id={"remove-from-navigation-#{item.page.public_id}"}
              icon="eye-off"
              label="Hide from navigation"
              click={JS.push("remove_from_navigation", value: %{id: item.page.public_id})}
            />
          </.list_row>
        </.list_card>
      </section>

      <section class="list-section">
        <h2 class="section-title">
          Other pages <span class="section-title__count">{@pagination.total_entries}</span>
        </h2>
        <.empty_state
          :if={@pagination.total_entries == 0}
          id="no-pages"
          emoji="📄"
          message="No other pages"
          subtitle="Create pages like an imprint, about or contact page."
        />
        <.list_card id="pages" stream hidden={@pagination.total_entries == 0}>
          <.list_row
            :for={{dom_id, page} <- @streams.pages}
            id={dom_id}
            navigate={edit_path(@site, page)}
          >
            <:leading><.page_tile page={page} /></:leading>
            {page.title}
            <:meta><.page_meta page={page} /></:meta>
            <:action
              id={"add-to-navigation-#{page.public_id}"}
              icon="eye"
              label="Show in navigation"
              click={JS.push("add_to_navigation", value: %{id: page.public_id})}
            />
            <:action
              id={"delete-page-#{page.public_id}"}
              icon="trash"
              label="Delete"
              click={JS.push("delete", value: %{id: page.public_id})}
              confirm="Are you sure?"
              danger
            />
          </.list_row>
        </.list_card>

        <.pagination
          pagination={@pagination}
          path={&~p"/sites/#{@site.public_id}/pages?page=#{&1}"}
        />
      </section>
    </.site_shell>
    """
  end

  attr :page, :map, required: true

  defp page_tile(assigns) do
    ~H"""
    <span :if={@page.emoji}>{@page.emoji}</span>
    <.icon :if={!@page.emoji} name="file-text" />
    """
  end

  attr :page, :map, required: true

  defp page_meta(assigns) do
    ~H"""
    <span>{@page.slug}</span>
    <.neutral_badge :if={@page.page_type != "default"}>
      {page_type_label(@page.page_type)}
    </.neutral_badge>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:site, socket.assigns.current_scope.site)
     |> assign(:page_title, "Pages")
     |> stream_configure(:pages, dom_id: &"page-#{&1.public_id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load(socket, params["page"])}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    page = Content.get_page!(scope, id)
    {:ok, _page} = Content.delete_page(scope, page)
    if page.add_to_navigation, do: Publishing.publish_site(scope)

    {:noreply,
     socket
     |> put_flash(:info, "Page was successfully deleted.")
     |> load(socket.assigns.pagination.page)}
  end

  def handle_event("add_to_navigation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    {:ok, _item} = Sites.add_to_navigation(scope, Content.get_page!(scope, id))
    navigation_changed(socket, "Page was successfully added to the navigation.")
  end

  def handle_event("remove_from_navigation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    :ok = Sites.remove_from_navigation(scope, Content.get_page!(scope, id))
    navigation_changed(socket, "Page was successfully removed from the navigation.")
  end

  def handle_event("move_up", %{"id" => id}, socket) do
    :ok = Sites.move_navigation_item_up(socket.assigns.current_scope, find_item(socket, id))
    navigation_changed(socket, "Page was successfully moved up.")
  end

  def handle_event("move_down", %{"id" => id}, socket) do
    :ok = Sites.move_navigation_item_down(socket.assigns.current_scope, find_item(socket, id))
    navigation_changed(socket, "Page was successfully moved down.")
  end

  defp find_item(socket, page_public_id) do
    socket.assigns.current_scope
    |> Sites.list_navigation_items()
    |> Enum.find(&(&1.page.public_id == page_public_id)) ||
      raise Ecto.NoResultsError, queryable: Feather.Sites.NavigationItem
  end

  defp navigation_changed(socket, message) do
    Publishing.publish_site(socket.assigns.current_scope)

    {:noreply,
     socket
     |> put_flash(:info, message)
     |> load(socket.assigns.pagination.page)}
  end

  defp load(socket, page) do
    scope = socket.assigns.current_scope
    pagination = Content.paginate_pages_outside_navigation(scope, page)

    socket
    |> assign(:navigation_items, Sites.list_navigation_items(scope))
    |> assign(:pagination, pagination)
    |> stream(:pages, pagination.entries, reset: true)
  end

  defp edit_path(site, page), do: ~p"/sites/#{site.public_id}/pages/#{page.public_id}/edit"

  defp page_type_label("books"), do: "Books"
  defp page_type_label("projects"), do: "Projects"
  defp page_type_label(other), do: other
end
