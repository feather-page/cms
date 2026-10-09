defmodule FeatherWeb.ProjectLive.Form do
  @moduledoc """
  Creates and edits projects: header image picker, title and slug, company,
  role, period, dates, status, type, short description, tags, block
  content and a list of links (added and removed with the `links_sort` /
  `links_drop` parameters of `inputs_for`). Every change is saved into
  the unpublished changes at once; a new project is created as a draft
  once its required fields are valid (see "Autosave" in
  `FeatherWeb.ContentForm`). Publish publishes them; Discard puts the
  published version back; Restore puts an earlier version into the
  unpublished changes.
  """
  use FeatherWeb, :live_view
  @behaviour FeatherWeb.ContentForm

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
        <:badge :if={@live_action == :edit and @publication_status != :published}>
          <.publication_badge id="publication-badge" status={@publication_status} />
        </:badge>
        <:badge :if={@live_action == :edit and @project.status}>
          <.status_badge id="status-badge">{status_label(@project.status)}</.status_badge>
        </:badge>
      </.header>

      <.editor_layout id="project" open={ContentForm.details_open?(@form)}>
        <:main>
          <.form
            for={@form}
            id="project-form"
            phx-change="autosave"
            phx-submit="autosave"
            phx-auto-recover="recover"
          >
            <.lock_version_field record={@project} />
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
              site={@current_scope.site}
              value={@editor_json}
              record={@project}
              status={ContentForm.autosave_status(@form, @changed_elsewhere?)}
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
          <.record_versions versions={@versions} record={@project} />
        </:details>
      </.editor_layout>

      <.content_actions
        id="project"
        noun="project"
        record={@project}
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

    project =
      case socket.assigns.live_action do
        :new -> %Project{site_id: scope.site.id}
        :edit -> scope |> Content.get_project!(params["id"]) |> Content.preload_images()
      end

    {:ok,
     socket
     |> assign(statuses: @statuses, project_types: @project_types)
     |> ContentForm.mount_record(project)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    page_title =
      case socket.assigns.live_action do
        :new -> "New project"
        :edit -> ContentForm.heading(socket.assigns.project, "Untitled project")
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _project} =
      Content.delete_project(socket.assigns.current_scope, socket.assigns.project)

    {:noreply,
     socket
     |> put_flash(:info, "The project was successfully deleted.")
     |> push_navigate(to: ~p"/sites/#{socket.assigns.site.public_id}/projects")}
  end

  def handle_event(event, params, socket), do: ContentForm.handle_event(event, params, socket)

  @impl true
  def handle_info(message, socket), do: ContentForm.handle_info(message, socket)

  @impl ContentForm
  def record(socket), do: socket.assigns.project

  @impl ContentForm
  def save_fields(socket, attrs, opts) do
    %{current_scope: scope, project: project} = socket.assigns

    with {:ok, project} <- Content.autosave(scope, project, attrs, opts),
         do: {:ok, project, socket}
  end

  @impl ContentForm
  def assign_record(socket, project), do: assign(socket, :project, project)

  @impl ContentForm
  def noun, do: "Project"

  @impl ContentForm
  def edit_path(socket, project),
    do: ~p"/sites/#{socket.assigns.site.public_id}/projects/#{project.public_id}/edit"

  defp status_label(status) do
    Enum.find_value(@statuses, status, fn {label, value} -> value == status && label end)
  end

  @impl ContentForm
  def assign_form(socket, params, action \\ nil) do
    changeset =
      socket.assigns.current_scope
      |> Content.change_project(socket.assigns.project, params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end
