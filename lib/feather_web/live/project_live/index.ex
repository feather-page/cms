defmodule FeatherWeb.ProjectLive.Index do
  @moduledoc """
  The projects of a site, most recently started first.
  """
  use FeatherWeb, :live_view

  alias Feather.Content
  alias Feather.Content.Project

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
        Projects
        <:actions>
          <.button
            variant="primary"
            navigate={~p"/sites/#{@site.public_id}/projects/new"}
            id="new-project"
          >
            <.icon name="plus" size={16} /> New Project
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@empty?}
        id="no-projects"
        emoji="🏗️"
        message="No projects yet"
        subtitle="Show your work and projects."
        action_label="New Project"
        action_navigate={~p"/sites/#{@site.public_id}/projects/new"}
      />

      <div id="projects" phx-update="stream" class="list-rows">
        <div :for={{dom_id, project} <- @streams.projects} id={dom_id} class="list-row">
          <.link navigate={edit_path(@site, project)} class="list-row__link">
            <div class="list-row__icon">
              <span :if={project.emoji}>{project.emoji}</span>
              <.icon :if={!project.emoji} name="rocket" />
            </div>
            <div class="list-row__content">
              <div class="list-row__title">{project.title}</div>
              <div class="list-row__meta">
                <span :if={project.company}>{project.company}</span>
                <span :if={project.role}>{project.role}</span>
                <span>{Project.display_period(project)}</span>
                <span class="badge list-row__badge--status">{status_label(project.status)}</span>
              </div>
            </div>
          </.link>
          <div class="list-row__actions">
            <.link navigate={edit_path(@site, project)} class="btn btn-sm btn-link" title="Edit">
              <.icon name="pencil" size={16} />
            </.link>
            <button
              type="button"
              id={"delete-project-#{project.public_id}"}
              class="btn btn-sm btn-link text-danger"
              title="Delete"
              aria-label="Delete"
              phx-click="delete"
              phx-value-id={project.public_id}
              data-confirm="Are you sure?"
            >
              <.icon name="trash" size={16} />
            </button>
          </div>
        </div>
      </div>
    </.site_shell>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    projects = Content.list_projects(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:site, socket.assigns.current_scope.site)
     |> assign(:page_title, "Projects")
     |> assign(:empty?, projects == [])
     |> stream_configure(:projects, dom_id: &"project-#{&1.public_id}")
     |> stream(:projects, projects)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    project = Content.get_project!(scope, id)
    {:ok, _project} = Content.delete_project(scope, project)

    {:noreply,
     socket
     |> put_flash(:info, "The project was successfully deleted.")
     |> assign(:empty?, Content.list_projects(scope) == [])
     |> stream_delete(:projects, project)}
  end

  defp edit_path(site, project),
    do: ~p"/sites/#{site.public_id}/projects/#{project.public_id}/edit"

  @doc false
  def status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()
end
