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
      deploy={@site_deploy}
      unread_mentions={@site_unread_mentions}
      active={:projects}
    >
      <.header>
        Projects
        <:actions :if={!@empty?}>
          <.button
            variant={:primary}
            icon="plus"
            navigate={~p"/sites/#{@site.public_id}/projects/new"}
            id="new-project"
          >
            New project
          </.button>
        </:actions>
      </.header>

      <.empty_state
        :if={@empty?}
        id="no-projects"
        layout={:page}
        plush_size={:xxl}
        plush="rocket"
        title="No projects yet"
      >
        Show your work and projects.
        <:action>
          <.button
            navigate={~p"/sites/#{@site.public_id}/projects/new"}
            variant={:primary}
            icon="plus"
          >
            Add your first project
          </.button>
        </:action>
      </.empty_state>

      <.list id="projects" phx-update="stream" class={@empty? && "hidden"}>
        <.list_row
          :for={{dom_id, project} <- @streams.projects}
          id={dom_id}
          navigate={edit_path(@site, project)}
          title={project.title}
          actions_label="Actions"
          menu={:always}
          trailing_on_phone={:meta}
        >
          <:leading><.tile emoji={project.emoji} icon="folder-kanban" /></:leading>
          <:meta>
            {period(project)}
            <span :if={project.status in ~w(paused abandoned)}>
              · {status_label(project.status)}
            </span>
            <span :if={byline(project) != ""}>· {byline(project)}</span>
          </:meta>
          <:trailing
            :let={place}
            :if={Content.publication_status(project) != :published}
            class="md:w-44 md:justify-start"
          >
            <.publication_badge
              status={Content.publication_status(project)}
              style={if place == :meta, do: :text, else: :dot}
            />
          </:trailing>
          <:action
            id={"delete-project-#{project.public_id}"}
            icon="trash-2"
            label="Delete"
            on_click={JS.push("delete", value: %{id: project.public_id})}
            confirm={"Delete the project “#{project.title}”?"}
            confirm_text={delete_text("project", project)}
            danger
          />
        </.list_row>
      </.list>
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

    socket =
      with %Project{} = project <- Content.get_project(scope, id),
           {:ok, _project} <- Content.delete_project(scope, project) do
        put_flash(socket, :info, "The project was successfully deleted.")
      else
        nil -> put_flash(socket, :error, "This project no longer exists.")
        {:error, _reason} -> put_flash(socket, :error, "The project could not be deleted.")
      end

    projects = Content.list_projects(scope)

    {:noreply,
     socket
     |> assign(:empty?, projects == [])
     |> stream(:projects, projects, reset: true)
     |> FeatherWeb.SiteAuth.refresh_deploy_status()}
  end

  defp edit_path(site, project),
    do: ~p"/sites/#{site.public_id}/projects/#{project.public_id}/edit"

  defp period(project) do
    if is_binary(project.period) and String.trim(project.period) != "" do
      String.replace(project.period, " - ", " – ")
    else
      finish = if project.ended_at, do: month(project.ended_at), else: "ongoing"
      "#{month(project.started_at)} – #{finish}"
    end
  end

  defp month(date), do: Calendar.strftime(date, "%m/%Y")

  defp byline(project),
    do: [project.company, project.role] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" · ")

  @doc false
  def status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()
end
