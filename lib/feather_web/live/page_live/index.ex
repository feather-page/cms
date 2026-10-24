defmodule FeatherWeb.PageLive.Index do
  @moduledoc """
  The pages of a site: the pages in the main navigation (ordered, move
  up/down, remove) and the other pages (20 per page, add to navigation).
  Navigation changes count as not deployed at once.
  """
  use FeatherWeb, :live_view

  alias Feather.{Content, Sites}
  alias Feather.Content.Page

  @gone "This page no longer exists."

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      unread_mentions={@site_unread_mentions}
      active={:pages}
    >
      <.header>
        Pages
        <:actions>
          <.button
            variant={:primary}
            icon="plus"
            navigate={~p"/sites/#{@site.public_id}/pages/new"}
            id="new-page"
          >
            New page
          </.button>
        </:actions>
      </.header>

      <section aria-labelledby="navigation-items-heading">
        <.section_heading id="navigation-items-heading" count={length(@navigation_items)}>
          In navigation
        </.section_heading>
        <.empty_state :if={@navigation_items == []} id="no-navigation-items" icon="list-plus">
          No pages in the navigation yet. Add one with “Show in navigation” on its row.
        </.empty_state>
        <.list id="navigation-items" class={@navigation_items == [] && "hidden"}>
          <.list_row
            :for={{item, index} <- Enum.with_index(@navigation_items)}
            id={"navigation-item-#{item.page.public_id}"}
            navigate={edit_path(@site, item.page)}
            title={item.page.title}
            actions_label="Actions"
            menu={:always}
            actions_class="md:w-[4.25rem] justify-end"
            trailing_on_phone={:meta}
          >
            <:leading><.tile emoji={item.page.emoji} icon="file-text" /></:leading>
            <:meta><.page_meta page={item.page} /></:meta>
            <:trailing
              :let={place}
              :if={Content.publication_status(item.page) != :published}
              class="md:w-44 md:justify-start"
            >
              <.publication_badge
                status={Content.publication_status(item.page)}
                style={if place == :meta, do: :text, else: :dot}
              />
            </:trailing>
            <:action
              id={"move-up-#{item.page.public_id}"}
              icon="chevron-up"
              label="Move up"
              on_click={JS.push("move_up", value: %{id: item.page.public_id})}
              disabled={index == 0}
              inline
            />
            <:action
              id={"move-down-#{item.page.public_id}"}
              icon="chevron-down"
              label="Move down"
              on_click={JS.push("move_down", value: %{id: item.page.public_id})}
              disabled={index == length(@navigation_items) - 1}
              inline
            />
            <:action
              id={"remove-from-navigation-#{item.page.public_id}"}
              icon="list-minus"
              label="Hide from navigation"
              on_click={JS.push("remove_from_navigation", value: %{id: item.page.public_id})}
            />
          </.list_row>
        </.list>
      </section>

      <section id="other-pages" aria-labelledby="pages-heading" class="mt-8" tabindex="-1">
        <.section_heading id="pages-heading" count={@pagination.total_entries}>
          Other pages
        </.section_heading>
        <.empty_state
          :if={@pagination.total_entries == 0}
          id="no-pages"
          icon="file-text"
          title="No other pages"
        >
          Create pages like an imprint, about or contact page.
          <:action>
            <.button navigate={~p"/sites/#{@site.public_id}/pages/new"} icon="plus">
              New page
            </.button>
          </:action>
        </.empty_state>
        <.list
          id="pages"
          phx-update="stream"
          class={@pagination.total_entries == 0 && "hidden"}
        >
          <.list_row
            :for={{dom_id, page} <- @streams.pages}
            id={dom_id}
            navigate={edit_path(@site, page)}
            title={page.title}
            actions_label="Actions"
            menu={:always}
            actions_class="md:w-[4.25rem] justify-end"
            trailing_on_phone={:meta}
          >
            <:leading><.tile emoji={page.emoji} icon="file-text" /></:leading>
            <:meta><.page_meta page={page} /></:meta>
            <:trailing
              :let={place}
              :if={Content.publication_status(page) != :published}
              class="md:w-44 md:justify-start"
            >
              <.publication_badge
                status={Content.publication_status(page)}
                style={if place == :meta, do: :text, else: :dot}
              />
            </:trailing>
            <:action
              id={"add-to-navigation-#{page.public_id}"}
              icon="list-plus"
              label="Show in navigation"
              on_click={JS.push("add_to_navigation", value: %{id: page.public_id})}
              inline
            />
            <:action
              id={"delete-page-#{page.public_id}"}
              icon="trash-2"
              label="Delete"
              on_click={JS.push("delete", value: %{id: page.public_id})}
              confirm={"Delete the page “#{page.title}”?"}
              confirm_text={delete_text("page", page)}
              danger
            />
          </.list_row>
        </.list>

        <.pagination
          pagination={@pagination}
          path={&~p"/sites/#{@site.public_id}/pages?page=#{&1}"}
        />
      </section>
    </.site_shell>
    """
  end

  attr :page, :map, required: true

  defp page_meta(assigns) do
    ~H"""
    <span>{@page.slug}</span>
    <span :if={@page.page_type != "default"}>· {page_type_label(@page.page_type)}</span>
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

    socket =
      with %Page{} = page <- Content.get_page(scope, id),
           {:ok, _page} <- Content.delete_page(scope, page) do
        socket
        |> FeatherWeb.SiteAuth.refresh_deploy_status()
        |> put_flash(:info, "Page was successfully deleted.")
      else
        nil -> put_flash(socket, :error, @gone)
        {:error, _reason} -> put_flash(socket, :error, "The page could not be deleted.")
      end

    {:noreply, load(socket, socket.assigns.pagination.page)}
  end

  def handle_event("add_to_navigation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with %Page{} = page <- Content.get_page(scope, id),
         {:ok, _item} <- Sites.add_to_navigation(scope, page) do
      socket
      |> navigation_changed("Page was successfully added to the navigation.")
      |> focus(["navigation-item-#{id}-menu-toggle"])
    else
      nil -> not_changed(socket, @gone)
      {:error, _reason} -> not_changed(socket, "The page could not be added to the navigation.")
    end
  end

  def handle_event("remove_from_navigation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Content.get_page(scope, id) do
      %Page{} = page ->
        :ok = Sites.remove_from_navigation(scope, page)

        {:noreply, socket} =
          navigation_changed(socket, "Page was successfully removed from the navigation.")

        # The row may land on another page of the list.
        ids =
          if Enum.any?(socket.assigns.pagination.entries, &(&1.public_id == id)),
            do: ["add-to-navigation-#{id}", "page-#{id}-menu-toggle"],
            else: ["other-pages"]

        focus({:noreply, socket}, ids)

      nil ->
        not_changed(socket, @gone)
    end
  end

  def handle_event("move_up", %{"id" => id}, socket), do: move(socket, id, :up)
  def handle_event("move_down", %{"id" => id}, socket), do: move(socket, id, :down)

  # The moved row changes its place and may disable the pressed button, so
  # the browser loses the focus: the "focus" event (assets/js/app.js) gives it
  # to the first enabled, visible one of the row's move buttons and its ⋮
  # menu toggle (phones).
  defp move(socket, id, direction) do
    scope = socket.assigns.current_scope

    case Enum.find(Sites.list_navigation_items(scope), &(&1.page.public_id == id)) do
      nil ->
        not_changed(socket, "This page is no longer in the navigation.")

      item ->
        :ok = move_item(scope, item, direction)

        {:noreply, socket} =
          navigation_changed(socket, "Page was successfully moved #{direction}.")

        ids = [
          "move-#{direction}-#{id}",
          "move-#{opposite(direction)}-#{id}",
          "navigation-item-#{id}-menu-toggle"
        ]

        {:noreply, push_event(socket, "focus", %{ids: ids})}
    end
  end

  # Showing or hiding a page moves its row to the other list, so the browser
  # loses the focus: it goes to the moved row's button for the way back (the
  # ⋮ menu toggle where that sits in the menu), or to the other pages when
  # the row is not on the shown page of them.
  defp focus({:noreply, socket}, ids), do: {:noreply, push_event(socket, "focus", %{ids: ids})}

  defp move_item(scope, item, :up), do: Sites.move_navigation_item_up(scope, item)
  defp move_item(scope, item, :down), do: Sites.move_navigation_item_down(scope, item)

  defp opposite(:up), do: :down
  defp opposite(:down), do: :up

  defp navigation_changed(socket, message) do
    {:noreply,
     socket
     |> FeatherWeb.SiteAuth.refresh_deploy_status()
     |> put_flash(:info, message)
     |> load(socket.assigns.pagination.page)}
  end

  defp not_changed(socket, message) do
    {:noreply,
     socket
     |> put_flash(:error, message)
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
