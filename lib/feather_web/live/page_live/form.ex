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
      <.header>
        {@page_title}
        <:subtitle>
          <.link navigate={~p"/sites/#{@site.public_id}/pages"}>Pages</.link> / {@page_title}
        </:subtitle>
      </.header>

      <.live_component
        module={HeaderImagePicker}
        id="page-header-image-picker"
        current_scope={@current_scope}
        header_image={@header_image}
        thumbnail_image={@thumbnail_image}
        emoji={@form[:emoji].value}
      />

      <.form for={@form} id="page-form" phx-change="validate" phx-submit="save">
        <.header_image_fields form={@form} />
        <.title_and_slug form={@form} />
        <.input
          field={@form[:tags]}
          label="Tags"
          help="Comma-separated, e.g. travel, photos"
          phx-debounce="300"
        />
        <.editor id="page-content-editor" field={@form[:content]} value={@editor_json} site={@site} />
        <.input field={@form[:page_type]} type="select" label="Page type" options={@page_types} />
        <.input field={@form[:add_to_navigation]} type="checkbox" label="Add to navigation" />

        <div class="d-flex gap-2">
          <.button variant="primary" phx-disable-with="Saving..." id="save-page">
            {if @live_action == :new, do: "Create Page", else: "Update Page"}
          </.button>
          <.button navigate={~p"/sites/#{@site.public_id}/pages"}>Cancel</.button>
        </div>
      </.form>
    </.site_shell>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    page =
      case socket.assigns.live_action do
        :new -> %Page{site_id: scope.site.id}
        :edit -> scope |> Content.get_page!(params["id"]) |> Content.preload_header_images()
      end

    {:ok,
     socket
     |> assign(:site, scope.site)
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new, do: "New Page", else: "Edit Page")
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
