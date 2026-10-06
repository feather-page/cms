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
    {"Open Source", "open_source"},
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
      <.header>
        {@page_title}
        <:subtitle>
          <.link navigate={~p"/sites/#{@site.public_id}/projects"}>Projects</.link> / {@page_title}
        </:subtitle>
      </.header>

      <.live_component
        module={HeaderImagePicker}
        id="project-header-image-picker"
        current_scope={@current_scope}
        header_image={@header_image}
        thumbnail_image={@thumbnail_image}
        emoji={@form[:emoji].value}
      />

      <.form for={@form} id="project-form" phx-change="validate" phx-submit="save">
        <.header_image_fields form={@form} />
        <.title_and_slug form={@form} />

        <div class="row">
          <div class="col">
            <.input field={@form[:company]} label="Company" phx-debounce="300" />
          </div>
          <div class="col">
            <.input field={@form[:role]} label="Role" phx-debounce="300" />
          </div>
        </div>

        <.input
          field={@form[:period]}
          label="Period"
          help="Optional. If empty, the dates below are used for display."
          phx-debounce="300"
        />

        <div class="row">
          <div class="col">
            <.input field={@form[:started_at]} type="date" label="Started at" />
          </div>
          <div class="col">
            <.input
              field={@form[:ended_at]}
              type="date"
              label="Ended at"
              help="Leave empty if ongoing"
            />
          </div>
        </div>

        <div class="row">
          <div class="col">
            <.input field={@form[:status]} type="select" label="Status" options={@statuses} />
          </div>
          <div class="col">
            <.input
              field={@form[:project_type]}
              type="select"
              label="Project type"
              options={@project_types}
            />
          </div>
        </div>

        <.input
          field={@form[:short_description]}
          type="textarea"
          label="Short description *"
          help="2-3 sentences for the overview. Shown on project cards."
          phx-debounce="300"
        />
        <.input
          field={@form[:tags]}
          label="Tags"
          help="Comma-separated, e.g. ruby, rails, web"
          phx-debounce="300"
        />
        <.editor
          id="project-content-editor"
          field={@form[:content]}
          value={@editor_json}
          site={@site}
        />

        <fieldset class="mb-3" id="project-links">
          <legend class="form-label fs-6">Links</legend>
          <.inputs_for :let={link} field={@form[:links]}>
            <div class="row mb-2 align-items-start" id={"project-link-#{link.index}"}>
              <input type="hidden" name="project[links_sort][]" value={link.index} />
              <div class="col-4">
                <.input field={link[:label]} placeholder="Label" phx-debounce="300" />
              </div>
              <div class="col-6">
                <.input field={link[:url]} type="url" placeholder="URL" phx-debounce="300" />
              </div>
              <div class="col-2">
                <button
                  type="button"
                  name="project[links_drop][]"
                  value={link.index}
                  id={"remove-link-#{link.index}"}
                  class="btn btn-outline-danger btn-sm"
                  phx-click={JS.dispatch("change")}
                >
                  Remove
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
            class="btn btn-outline-secondary btn-sm"
            phx-click={JS.dispatch("change")}
          >
            Add Link
          </button>
        </fieldset>

        <div class="d-flex gap-2">
          <.button variant="primary" phx-disable-with="Saving..." id="save-project">
            {if @live_action == :new, do: "Create Project", else: "Update Project"}
          </.button>
          <.button navigate={~p"/sites/#{@site.public_id}/projects"}>Cancel</.button>
        </div>
      </.form>
    </.site_shell>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    project =
      case socket.assigns.live_action do
        :new -> %Project{site_id: scope.site.id}
        :edit -> scope |> Content.get_project!(params["id"]) |> Content.preload_header_images()
      end

    {:ok,
     socket
     |> assign(:site, scope.site)
     |> assign(
       :page_title,
       if(socket.assigns.live_action == :new, do: "New Project", else: "Edit Project")
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
      |> Content.change_project(socket.assigns.project, params)
      |> Map.put(:action, action)

    socket
    |> assign(:params, params)
    |> assign(:form, to_form(changeset))
  end
end
