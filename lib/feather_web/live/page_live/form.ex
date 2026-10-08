defmodule FeatherWeb.PageLive.Form do
  @moduledoc """
  Creates and edits pages: header image picker, title and slug (slug
  suggested from the title), tags, Editor.js content, page type and the
  "add to navigation" flag. A save that changes the navigation publishes
  the site.

  Unlike Rails, the form has no "created at" field: the creation date of a
  page is not shown anywhere on the generated site.
  """
  use FeatherWeb, :live_view

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
        <:badge :if={@live_action == :edit and @page.add_to_navigation}>
          <.status_badge id="status-badge">In navigation</.status_badge>
        </:badge>
      </.header>

      <.editor_layout id="page" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form for={@form} id="page-form" phx-change="validate" phx-submit="save">
            <.header_image_fields form={@form} />
            <.title_field field={@form[:title]} />
            <.editor
              id="page-content-editor"
              field={@form[:content]}
              value={@editor_json}
              site={@site}
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
        </:details>
      </.editor_layout>

      <.action_bar sticky>
        <button
          type="submit"
          form="page-form"
          id="save-page"
          class="btn btn-primary"
          phx-disable-with="Saving..."
        >
          {if @live_action == :new, do: "Create page", else: "Save"}
        </button>
        <.link navigate={~p"/sites/#{@site.public_id}/pages"} class="btn btn-light">Cancel</.link>
        <:danger :if={@live_action == :edit}>
          <button
            type="button"
            id="delete-page"
            class="btn btn-outline-danger"
            phx-click="delete"
            data-confirm="Delete this page?"
          >
            <.icon name="trash-2" size={16} /> Delete
          </button>
        </:danger>
      </.action_bar>
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
     |> assign(:site, scope.site)
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new,
         do: "New page",
         else: ContentForm.heading(page, "Untitled page")
       )
     )
     |> assign(:page_types, @page_types)
     |> assign(:page, page)
     |> assign(:header_image, ContentForm.loaded(page.header_image))
     |> assign(:thumbnail_image, ContentForm.loaded(page.thumbnail_image))
     |> assign(:slug_touched?, ContentForm.present?(page.slug))
     |> assign(:editor_json, ContentForm.editor_json(scope, page))
     |> assign_form(%{})}
  end

  @impl true
  def handle_event("validate", %{"page" => page_params} = params, socket) do
    socket =
      assign(
        socket,
        :slug_touched?,
        socket.assigns.slug_touched? or ContentForm.slug_target?(params, "page")
      )

    page_params =
      ContentForm.maybe_suggest_slug(
        page_params,
        params,
        "page",
        socket.assigns.current_scope,
        socket.assigns.slug_touched?
      )

    {:noreply, assign_form(socket, page_params, :validate)}
  end

  def handle_event("save", %{"page" => page_params}, socket) do
    %{current_scope: scope, page: page, live_action: action} = socket.assigns

    result =
      case action do
        :new -> Content.create_page(scope, page_params)
        :edit -> Content.update_page(scope, page, page_params)
      end

    case result do
      {:ok, saved} ->
        if saved.add_to_navigation != page.add_to_navigation, do: Publishing.publish_site(scope)
        message = if action == :new, do: "created", else: "updated"

        {:noreply,
         socket
         |> put_flash(:info, "Page was successfully #{message}.")
         |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/pages")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         assign_form(socket, page_params, if(action == :new, do: :insert, else: :update))}
    end
  end

  def handle_event("delete", _params, socket) do
    %{current_scope: scope, page: page} = socket.assigns
    {:ok, _page} = Content.delete_page(scope, page)
    if page.add_to_navigation, do: Publishing.publish_site(scope)

    {:noreply,
     socket
     |> put_flash(:info, "Page was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/pages")}
  end

  @impl true
  def handle_info({HeaderImagePicker, change}, socket) do
    params = ContentForm.put_picker_change(socket.assigns.params, change)

    {:noreply,
     socket
     |> assign(ContentForm.picker_assigns(change))
     |> assign_form(params, socket.assigns.form.source.action)}
  end

  defp assign_form(socket, params, action \\ nil) do
    changeset =
      socket.assigns.current_scope
      |> Content.change_page(socket.assigns.page, params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end
