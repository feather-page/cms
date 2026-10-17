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

  alias Feather.{Content, Publishing}
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
      deploy={@site_deploy}
      active={:projects}
    >
      <:bar>
        <.breadcrumbs label="Breadcrumb">
          <:crumb navigate={~p"/sites/#{@site.public_id}/projects"}>Projects</:crumb>
          <:crumb>{@page_title}</:crumb>
        </.breadcrumbs>
        <.publication_badge
          :if={@live_action == :edit}
          id="publication-badge"
          status={@publication_status}
          live={Publishing.live?(@site_deploy.targets, @published_version)}
        />
      </:bar>
      <:bar_actions>
        <div id="publish-actions" class="flex items-center gap-3">
          <.editor_status editor="project-content-editor" />
          <div class="max-md:hidden">
            <.content_actions
              id="project"
              noun="project"
              record={@project}
              form={@form}
              status={@publication_status}
              changed_elsewhere?={@changed_elsewhere?}
            />
          </div>
        </div>
      </:bar_actions>

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
            <div id="project-lead" class="editor-lead-field mb-6">
              <.input
                field={@form[:short_description]}
                type="textarea"
                label="Short description"
                hide_label
                class="editor-lead textarea-ghost"
                placeholder="Short description"
                help="Two or three sentences, shown on the project cards. Required."
                rows="2"
                phx-debounce="300"
              />
            </div>
            <.editor
              id="project-content-editor"
              site={@current_scope.site}
              value={@editor_json}
              record={@project}
              status={ContentForm.autosave_status(@form, @changed_elsewhere?)}
            />

            <fieldset class="fieldset mt-8" id="project-links">
              <legend class="mb-3 text-base font-semibold">Links</legend>
              <.inputs_for :let={link} field={@form[:links]}>
                <div
                  class="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-x-2 max-sm:mb-4 sm:grid-cols-[12rem_minmax(0,1fr)_auto]"
                  id={"project-link-#{link.index}"}
                >
                  <input type="hidden" name="project[links_sort][]" value={link.index} />
                  <div class="max-sm:col-start-1 max-sm:row-start-1">
                    <.input
                      field={link[:label]}
                      placeholder="Label"
                      label="Label"
                      hide_label
                      phx-debounce="300"
                    />
                  </div>
                  <div class="max-sm:col-start-1 max-sm:row-start-2">
                    <.input
                      field={link[:url]}
                      type="url"
                      placeholder="https://"
                      label="URL"
                      hide_label
                      phx-debounce="300"
                    />
                  </div>
                  <button
                    type="button"
                    name="project[links_drop][]"
                    value={link.index}
                    id={"remove-link-#{link.index}"}
                    class="btn btn-ghost btn-square mt-1 max-sm:col-start-2 max-sm:row-start-1"
                    title="Remove link"
                    aria-label="Remove link"
                    phx-click={JS.dispatch("change")}
                  >
                    <.icon name="trash-2" />
                  </button>
                </div>
              </.inputs_for>
              <input type="hidden" name="project[links_drop][]" />
              <div>
                <button
                  type="button"
                  name="project[links_sort][]"
                  value="new"
                  id="add-link"
                  class="btn btn-sm btn-ghost"
                  phx-click={JS.dispatch("change")}
                >
                  <.icon name="plus" /> Add link
                </button>
              </div>
            </fieldset>
          </.form>
        </:main>
        <:details>
          <.slug_field field={@form[:slug]} form="project-form" />
          <div class="grid gap-x-4 sm:grid-cols-2 lg:grid-cols-1">
            <div>
              <.input
                field={@form[:company]}
                label="Company"
                form="project-form"
                phx-debounce="300"
              />
            </div>
            <div>
              <.input
                field={@form[:role]}
                label="Role"
                form="project-form"
                phx-debounce="300"
              />
            </div>
            <div class="sm:col-span-2 lg:col-span-1">
              <.input
                field={@form[:period]}
                label="Period"
                help="Optional. If empty, the dates are shown."
                form="project-form"
                phx-debounce="300"
              />
            </div>
            <div>
              <.input
                field={@form[:started_at]}
                type="date"
                label="Started at"
                form="project-form"
              />
            </div>
            <div>
              <.input
                field={@form[:ended_at]}
                type="date"
                label="Ended at"
                help="Leave empty if ongoing"
                form="project-form"
              />
            </div>
            <div>
              <.input
                field={@form[:status]}
                type="select"
                label="Status"
                options={@statuses}
                form="project-form"
              />
            </div>
            <div>
              <.input
                field={@form[:project_type]}
                type="select"
                label="Project type"
                options={@project_types}
                form="project-form"
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

      <.action_bar
        sticky
        id="action-bar"
        class="mt-6 items-center md:hidden [&_.join]:flex-1 [&_.join>.btn]:flex-1"
      >
        <.editor_status
          editor="project-content-editor"
          place={:bottom}
        />
        <.content_actions
          id="project"
          noun="project"
          record={@project}
          form={@form}
          status={@publication_status}
          changed_elsewhere?={@changed_elsewhere?}
          place={:bottom}
        />
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
    %{current_scope: scope, project: project} = socket.assigns

    socket =
      with %Project{} = project <- Content.get_project(scope, project.public_id),
           {:ok, _project} <- Content.delete_project(scope, project) do
        put_flash(socket, :info, "The project was successfully deleted.")
      else
        nil -> put_flash(socket, :error, "This project no longer exists.")
        {:error, _reason} -> put_flash(socket, :error, "The project could not be deleted.")
      end

    {:noreply, push_navigate(socket, to: ~p"/sites/#{socket.assigns.site.public_id}/projects")}
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
