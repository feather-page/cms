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
            <.icon name="plus" size={16} /> New project
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@empty?}
        id="no-projects"
        emoji="🏗️"
        message="No projects yet"
        subtitle="Show your work and projects."
      />

      <.list_card id="projects" stream hidden={@empty?}>
        <.list_row
          :for={{dom_id, project} <- @streams.projects}
          id={dom_id}
          navigate={edit_path(@site, project)}
        >
          <:leading>
            <span :if={project.emoji}>{project.emoji}</span>
            <.icon :if={!project.emoji} name="rocket" />
          </:leading>
          {project.title}
          <:meta>
            <span class="list-row__date">{Project.display_period(project)}</span>
            <.neutral_badge>{status_label(project.status)}</.neutral_badge>
            <span :if={byline(project) != ""}>{byline(project)}</span>
          </:meta>
          <:action
            id={"delete-project-#{project.public_id}"}
            icon="trash"
            label="Delete"
            click={JS.push("delete", value: %{id: project.public_id})}
            confirm="Are you sure?"
            danger
          />
        </.list_row>
      </.list_card>
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

  defp byline(project),
    do: [project.company, project.role] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" · ")

  @doc false
  def status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()
end
