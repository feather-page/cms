defmodule FeatherWeb.PageLive.Form do
  @moduledoc """
  Creates and edits pages: header image picker, title and slug (slug
  suggested from the title), tags, block content, page type and the
  "add to navigation" flag. A save that changes the navigation publishes
  the site. Every change is saved into the unpublished changes at once;
  the first input that gives the page a valid slug creates it as a draft
  (see "Autosave" in `FeatherWeb.ContentForm`). Publish publishes them;
  Discard puts the published version back; Restore puts an earlier
  version into the unpublished changes.

  Unlike Rails, the form has no "created at" field: the creation date of a
  page is not shown anywhere on the generated site.
  """
  use FeatherWeb, :live_view
  @behaviour FeatherWeb.ContentForm

  import FeatherWeb.ContentFormComponents

  alias Feather.{Content, Publishing}
  alias Feather.Content.Page
  alias FeatherWeb.{ContentForm, HeaderImagePicker}

  @page_types [{"Default", "default"}, {"Books", "books"}, {"Projects", "projects"}]

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
      <.header back={~p"/sites/#{@site.public_id}/pages"} back_label="Pages" truncate>
        {@page_title}
        <:badge :if={@live_action == :edit and @publication_status != :published}>
          <.publication_badge id="publication-badge" status={@publication_status} />
        </:badge>
        <:badge :if={@live_action == :edit and @page.add_to_navigation}>
          <.status_badge id="status-badge">In navigation</.status_badge>
        </:badge>
      </.header>

      <.editor_layout id="page" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form
            for={@form}
            id="page-form"
            phx-change="autosave"
            phx-submit="autosave"
            phx-auto-recover="recover"
          >
            <.lock_version_field record={@page} />
            <.header_image_fields form={@form} />
            <.title_field field={@form[:title]} />
            <.editor
              id="page-content-editor"
              site={@current_scope.site}
              value={@editor_json}
              record={@page}
              status={ContentForm.autosave_status(@form, @changed_elsewhere?)}
            />
          </.form>
        </:main>
        <:details>
          <.slug_field field={@form[:slug]} form="page-form" />
          <.input
            field={@form[:tags]}
            label="Tags"
            help="Comma-separated, e.g. travel, photos"
            form="page-form"
            phx-debounce="300"
          />
          <.input
            field={@form[:page_type]}
            type="select"
            label="Page type"
            options={@page_types}
            form="page-form"
          />
          <.input
            field={@form[:add_to_navigation]}
            type="checkbox"
            label="Add to navigation"
            switch
            form="page-form"
          />
          <.live_component
            module={HeaderImagePicker}
            id="page-header-image-picker"
            current_scope={@current_scope}
            header_image={@header_image}
            thumbnail_image={@thumbnail_image}
            emoji={@form[:emoji].value}
          />
          <.record_versions versions={@versions} record={@page} />
        </:details>
      </.editor_layout>

      <.content_actions
        id="page"
        noun="page"
        record={@page}
        form={@form}
        status={@publication_status}
        changed_elsewhere?={@changed_elsewhere?}
      />
    </.site_shell>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    page =
      case socket.assigns.live_action do
        :new -> %Page{site_id: scope.site.id}
        :edit -> scope |> Content.get_page!(params["id"]) |> Content.preload_images()
      end

    {:ok,
     socket
     |> assign(:page_types, @page_types)
     |> ContentForm.mount_record(page)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    page_title =
      case socket.assigns.live_action do
        :new -> "New page"
        :edit -> ContentForm.heading(socket.assigns.page, "Untitled page")
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    %{current_scope: scope, page: page} = socket.assigns
    {:ok, _page} = Content.delete_page(scope, page)
    if page.add_to_navigation, do: Publishing.publish_site(scope)

    {:noreply,
     socket
     |> put_flash(:info, "Page was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/pages")}
  end

  def handle_event(event, params, socket), do: ContentForm.handle_event(event, params, socket)

  @impl true
  def handle_info(message, socket), do: ContentForm.handle_info(message, socket)

  @impl ContentForm
  def record(socket), do: socket.assigns.page

  # A change of the navigation publishes the site, the navigation is not
  # versioned.
  @impl ContentForm
  def save_fields(socket, attrs, opts) do
    %{current_scope: scope, page: page} = socket.assigns

    with {:ok, saved} <- Content.autosave(scope, page, attrs, opts) do
      if saved.add_to_navigation != page.add_to_navigation, do: Publishing.publish_site(scope)
      {:ok, saved, socket}
    end
  end

  @impl ContentForm
  def assign_record(socket, page), do: assign(socket, :page, page)

  @impl ContentForm
  def noun, do: "Page"

  @impl ContentForm
  def edit_path(socket, page),
    do: ~p"/sites/#{socket.assigns.site.public_id}/pages/#{page.public_id}/edit"

  @impl ContentForm
  def assign_form(socket, params, action \\ nil) do
    changeset =
      socket.assigns.current_scope
      |> Content.change_page(socket.assigns.page, params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end
