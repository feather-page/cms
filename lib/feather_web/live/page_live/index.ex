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
            <.icon name="plus" size={16} /> New Page
          </.button>
        </:actions>
      </.header>

      <h2 class="labeled-divider h6 text-body-secondary text-uppercase">Pages in navigation</h2>
      <p :if={@navigation_items == []} id="no-navigation-items" class="text-body-secondary">
        No pages in the navigation yet.
      </p>
      <div id="navigation-items" class="list-rows mb-4">
        <div
          :for={{item, index} <- Enum.with_index(@navigation_items)}
          id={"navigation-item-#{item.page.public_id}"}
          class="list-row"
        >
          <div class="list-row__icon">
            <span :if={item.page.emoji}>{item.page.emoji}</span>
            <.icon :if={!item.page.emoji} name="file-text" />
          </div>
          <div class="list-row__content">
            <div class="list-row__title">{item.page.title}</div>
            <div class="list-row__meta">{item.page.slug}</div>
          </div>
          <div class="list-row__actions">
            <button
              type="button"
              id={"move-up-#{item.page.public_id}"}
              class="btn btn-sm btn-link"
              title="Move up"
              aria-label="Move up"
              disabled={index == 0}
              phx-click="move_up"
              phx-value-id={item.page.public_id}
            >
              <.icon name="chevron-up" size={16} />
            </button>
            <button
              type="button"
              id={"move-down-#{item.page.public_id}"}
              class="btn btn-sm btn-link"
              title="Move down"
              aria-label="Move down"
              disabled={index == length(@navigation_items) - 1}
              phx-click="move_down"
              phx-value-id={item.page.public_id}
            >
              <.icon name="chevron-down" size={16} />
            </button>
            <.link navigate={edit_path(@site, item.page)} class="btn btn-sm btn-link" title="Edit">
              <.icon name="pencil" size={16} />
            </.link>
            <button
              type="button"
              id={"remove-from-navigation-#{item.page.public_id}"}
              class="btn btn-sm btn-link text-danger"
              title="Remove from navigation"
              aria-label="Remove from navigation"
              phx-click="remove_from_navigation"
              phx-value-id={item.page.public_id}
            >
              <.icon name="minus" size={16} />
            </button>
          </div>
        </div>
      </div>

      <h2 class="labeled-divider h6 text-body-secondary text-uppercase">Other pages</h2>
      <.empty_state
        :if={@pagination.total_entries == 0}
        id="no-pages"
        emoji="📄"
        message="No other pages"
        subtitle="Create pages like an imprint, about or contact page."
        action_label="New Page"
        action_navigate={~p"/sites/#{@site.public_id}/pages/new"}
      />
      <div id="pages" phx-update="stream" class="list-rows">
        <div :for={{dom_id, page} <- @streams.pages} id={dom_id} class="list-row">
          <.link navigate={edit_path(@site, page)} class="list-row__link">
            <div class="list-row__icon">
              <span :if={page.emoji}>{page.emoji}</span>
              <.icon :if={!page.emoji} name="file-text" />
            </div>
            <div class="list-row__content">
              <div class="list-row__title">{page.title}</div>
              <div class="list-row__meta">
                {page.slug}
                <span :if={page.page_type != "default"} class="list-row__tag">
                  {page_type_label(page.page_type)}
                </span>
              </div>
            </div>
          </.link>
          <div class="list-row__actions">
            <button
              type="button"
              id={"add-to-navigation-#{page.public_id}"}
              class="btn btn-sm btn-link text-success"
              title="Add to navigation"
              aria-label="Add to navigation"
              phx-click="add_to_navigation"
              phx-value-id={page.public_id}
            >
              <.icon name="plus" size={16} />
            </button>
            <.link navigate={edit_path(@site, page)} class="btn btn-sm btn-link" title="Edit">
              <.icon name="pencil" size={16} />
            </.link>
            <button
              type="button"
              id={"delete-page-#{page.public_id}"}
              class="btn btn-sm btn-link text-danger"
              title="Delete"
              aria-label="Delete"
              phx-click="delete"
              phx-value-id={page.public_id}
              data-confirm="Are you sure?"
            >
              <.icon name="trash" size={16} />
            </button>
          </div>
        </div>
      </div>

      <.pagination pagination={@pagination} path={&~p"/sites/#{@site.public_id}/pages?page=#{&1}"} />
    </.site_shell>
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
