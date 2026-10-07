defmodule FeatherWeb.DeploymentTargetLive.Index do
  @moduledoc """
  The deployment targets of a site, with a button to deploy each.

  The deploy pipeline broadcasts `{:site_notice, %{message: message, url:
  url}}` when a deploy finishes. The site shell shows it as a toast (see
  `FeatherWeb.SiteAuth`); this page also receives it
  (`forward_site_notices`) and refreshes the list so the "deploying" badges
  are current.
  """
  use FeatherWeb, :live_view

  alias Feather.Publishing

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      preview_path={@site_preview_path}
      active={:deployments}
    >
      <.header>
        Deployment targets
        <:subtitle>Where {@current_scope.site.title} is published</:subtitle>
      </.header>

      <p :if={@targets == []} id="no-deployment-targets" class="text-body-secondary">
        No deployment targets configured.
      </p>

      <ul :if={@targets != []} id="deployment-targets" class="list-group">
        <li
          :for={target <- @targets}
          id={"target-#{target.public_id}"}
          class="list-group-item d-flex align-items-center gap-3"
        >
          <.icon name="globe" />
          <div class="flex-grow-1">
            <div class="fw-semibold">{target.public_hostname}</div>
            <div class="small text-body-secondary">
              <span class="target-type">{type_label(target.type)}</span>
              · <span class="target-provider">{target.provider}</span>
              <span
                :if={target.deploying}
                id={"deploying-#{target.public_id}"}
                class="badge text-bg-warning ms-1"
              >
                <.icon name="loader-circle" size={12} class="spin" /> Deploying
              </span>
            </div>
          </div>
          <.button
            id={"deploy-#{target.public_id}"}
            size="sm"
            variant="primary"
            phx-click={JS.push("deploy", value: %{id: target.public_id})}
            disabled={target.deploying}
          >
            <.icon name="rocket" size={16} /> Deploy
          </.button>
          <.button
            id={"edit-#{target.public_id}"}
            size="sm"
            navigate={
              ~p"/sites/#{@current_scope.site.public_id}/deployments/#{target.public_id}/edit"
            }
            title="Edit"
            aria-label="Edit"
          >
            <.icon name="pencil" size={16} />
          </.button>
        </li>
      </ul>
    </.site_shell>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Deployments")
     |> assign(:forward_site_notices, true)
     |> assign_targets()}
  end

  @impl true
  def handle_event("deploy", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    target = Publishing.get_target!(scope, id)
    # Returns at once; a deploy already running coalesces with this one.
    :ok = Publishing.deploy(scope, target)

    {:noreply,
     socket
     |> put_flash(:info, "A deployment was triggered for this deployment target.")
     |> assign_targets()}
  end

  @impl true
  def handle_info({:site_notice, _notice}, socket) do
    {:noreply, assign_targets(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp assign_targets(socket) do
    assign(socket, :targets, Publishing.list_targets(socket.assigns.current_scope))
  end

  @doc false
  def type_label("staging"), do: "Staging"
  def type_label("production"), do: "Production"
  def type_label("backup"), do: "Backup"
  def type_label(type), do: type
end
