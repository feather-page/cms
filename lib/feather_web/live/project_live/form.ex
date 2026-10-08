defmodule FeatherWeb.ProjectLive.Form do
  @moduledoc """
  Creates and edits projects: header image picker, title and slug, company,
  role, period, dates, status, type, short description, tags, Editor.js
  content and a list of links (added and removed with the `links_sort` /
  `links_drop` parameters of `inputs_for`).
  """
  use FeatherWeb, :live_view

  import FeatherWeb.ContentFormComponents

  alias Feather.Content
  alias Feather.Content.Project
  alias FeatherWeb.{ContentForm, HeaderImagePicker}

  @statuses [
    {"Ongoing", "ongoing"},
    {"Completed", "completed"},
    {"Paused", "paused"},
    {"Abandoned", "abandoned"}
  ]

  @project_types [
    {"Professional", "professional"},
    {"Personal", "personal"},
    {"Open source", "open_source"},
    {"Freelance", "freelance"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      preview_path={@site_preview_path}
      active={:projects}
    >
      <.header back={~p"/sites/#{@site.public_id}/projects"} back_label="Projects" truncate>
        {@page_title}
        <:badge :if={@live_action == :edit and @project.status}>
          <.status_badge>{status_label(@project.status)}</.status_badge>
        </:badge>
      </.header>

      <.editor_layout id="project" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form for={@form} id="project-form" phx-change="validate" phx-submit="save">
            <.header_image_fields form={@form} />
            <.title_field field={@form[:title]} />
            <.input
              field={@form[:short_description]}
              type="textarea"
              label="Short description"
              help="Required. Two or three sentences, shown on the project cards."
              rows="3"
              phx-debounce="300"
            />
            <.editor
              id="project-content-editor"
              field={@form[:content]}
              value={@editor_json}
              site={@site}
            />

            <fieldset class="mb-3" id="project-links">
              <legend class="form-label">Links</legend>
              <.inputs_for :let={link} field={@form[:links]}>
                <div class="link-row row g-2 mb-2" id={"project-link-#{link.index}"}>
                  <input type="hidden" name="project[links_sort][]" value={link.index} />
                  <div class="col-12 col-sm-4">
                    <.input
                      field={link[:label]}
                      placeholder="Label"
                      aria-label="Label"
                      wrapper_class={nil}
                      phx-debounce="300"
                    />
                  </div>
                  <div class="col col-sm">
                    <.input
                      field={link[:url]}
                      type="url"
                      placeholder="https://"
                      aria-label="URL"
                      wrapper_class={nil}
                      phx-debounce="300"
                    />
                  </div>
                  <div class="col-auto">
                    <button
                      type="button"
                      name="project[links_drop][]"
                      value={link.index}
                      id={"remove-link-#{link.index}"}
                      class="btn btn-link link-row__remove"
                      title="Remove link"
                      aria-label="Remove link"
                      phx-click={JS.dispatch("change")}
                    >
                      <.icon name="trash-2" size={18} />
                    </button>
                  </div>
                </div>
              </.inputs_for>
              <input type="hidden" name="project[links_drop][]" />
              <button
                type="button"
                name="project[links_sort][]"
                value="new"
                id="add-link"
                class="btn btn-light btn-sm"
                phx-click={JS.dispatch("change")}
              >
                <.icon name="plus" size={16} /> Add link
              </button>
            </fieldset>
          </.form>
        </:main>
        <:details>
          <.slug_field field={@form[:slug]} form="project-form" />
          <div class="row g-3 mb-3">
            <div class="col-12 col-sm-6 col-lg-12">
              <.input
                field={@form[:company]}
                label="Company"
                form="project-form"
                wrapper_class={nil}
                phx-debounce="300"
              />
            </div>
            <div class="col-12 col-sm-6 col-lg-12">
              <.input
                field={@form[:role]}
                label="Role"
                form="project-form"
                wrapper_class={nil}
                phx-debounce="300"
              />
            </div>
            <div class="col-12">
              <.input
                field={@form[:period]}
                label="Period"
                help="Optional. If empty, the dates are shown."
                form="project-form"
                wrapper_class={nil}
                phx-debounce="300"
              />
            </div>
            <div class="col-12 col-sm-6 col-lg-12">
              <.input
                field={@form[:started_at]}
                type="date"
                label="Started at"
                form="project-form"
                wrapper_class={nil}
              />
            </div>
            <div class="col-12 col-sm-6 col-lg-12">
              <.input
                field={@form[:ended_at]}
                type="date"
                label="Ended at"
                help="Leave empty if ongoing"
                form="project-form"
                wrapper_class={nil}
              />
            </div>
            <div class="col-12 col-sm-6 col-lg-12">
              <.input
                field={@form[:status]}
                type="select"
                label="Status"
                options={@statuses}
                form="project-form"
                wrapper_class={nil}
              />
            </div>
            <div class="col-12 col-sm-6 col-lg-12">
              <.input
                field={@form[:project_type]}
                type="select"
                label="Project type"
                options={@project_types}
                form="project-form"
                wrapper_class={nil}
              />
            </div>
          </div>
          <.input
            field={@form[:tags]}
            label="Tags"
            help="Comma-separated, e.g. ruby, rails, web"
            form="project-form"
            phx-debounce="300"
          />
          <.live_component
            module={HeaderImagePicker}
            id="project-header-image-picker"
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
          form="project-form"
          id="save-project"
          class="btn btn-primary"
          phx-disable-with="Saving..."
        >
          {if @live_action == :new, do: "Create project", else: "Save"}
        </button>
        <.link navigate={~p"/sites/#{@site.public_id}/projects"} class="btn btn-light">
          Cancel
        </.link>
        <:danger :if={@live_action == :edit}>
          <button
            type="button"
            id="delete-project"
            class="btn btn-outline-danger"
            phx-click="delete"
            data-confirm="Delete this project?"
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

    project =
      case socket.assigns.live_action do
        :new -> %Project{site_id: scope.site.id}
        :edit -> scope |> Content.get_project!(params["id"]) |> Content.preload_images()
      end

    {:ok,
     socket
     |> assign(:site, scope.site)
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new,
         do: "New project",
         else: ContentForm.heading(project, "Untitled project")
       )
     )
     |> assign(statuses: @statuses, project_types: @project_types)
     |> assign(:project, project)
     |> assign(:header_image, ContentForm.loaded(project.header_image))
     |> assign(:thumbnail_image, ContentForm.loaded(project.thumbnail_image))
     |> assign(:slug_touched?, ContentForm.present?(project.slug))
     |> assign(:editor_json, ContentForm.editor_json(scope, project))
     |> assign_form(%{})}
  end

  @impl true
  def handle_event("validate", %{"project" => project_params} = params, socket) do
    socket =
      assign(
        socket,
        :slug_touched?,
        socket.assigns.slug_touched? or ContentForm.slug_target?(params, "project")
      )

    project_params =
      ContentForm.maybe_suggest_slug(
        project_params,
        params,
        "project",
        socket.assigns.current_scope,
        socket.assigns.slug_touched?
      )

    {:noreply, assign_form(socket, project_params, :validate)}
  end

  def handle_event("save", %{"project" => project_params}, socket) do
    %{current_scope: scope, project: project, live_action: action} = socket.assigns

    result =
      case action do
        :new -> Content.create_project(scope, project_params)
        :edit -> Content.update_project(scope, project, project_params)
      end

    case result do
      {:ok, _project} ->
        message = if action == :new, do: "created", else: "updated"

        {:noreply,
         socket
         |> put_flash(:info, "The project was successfully #{message}.")
         |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/projects")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         assign_form(socket, project_params, if(action == :new, do: :insert, else: :update))}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, _project} =
      Content.delete_project(socket.assigns.current_scope, socket.assigns.project)

    {:noreply,
     socket
     |> put_flash(:info, "The project was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/projects")}
  end

  @impl true
  def handle_info({HeaderImagePicker, change}, socket) do
    params = ContentForm.put_picker_change(socket.assigns.params, change)

    {:noreply,
     socket
     |> assign(ContentForm.picker_assigns(change))
     |> assign_form(params, socket.assigns.form.source.action)}
  end

  defp status_label(status) do
    Enum.find_value(@statuses, status, fn {label, value} -> value == status && label end)
  end

  defp assign_form(socket, params, action \\ nil) do
    changeset =
      socket.assigns.current_scope
      |> Content.change_project(socket.assigns.project, params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end
