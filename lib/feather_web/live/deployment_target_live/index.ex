defmodule FeatherWeb.DeploymentTargetLive.Index do
  @moduledoc """
  The deployment targets of a site, with a button to deploy each.

  Subscribes to the site's notices (`"site:<site id>:notices"`): the deploy
  pipeline broadcasts `{:site_notice, %{message: message, url: url}}` when a
  deploy finishes. The notice is shown as a flash with the link, and the
  list is refreshed so the "deploying" badges are current.
  """
  use FeatherWeb, :live_view

  alias Feather.Publishing

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
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
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    site = socket.assigns.current_scope.site

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Feather.PubSub, "site:#{site.id}:notices")
    end

    {:ok,
     socket
     |> assign(:page_title, "Deployments")
     |> assign_targets()}
  end

  @impl true
  def handle_event("deploy", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    target = Publishing.get_target!(scope, id)
    {kind, message} = deploy_flash(Publishing.deploy(scope, target))

    {:noreply,
     socket
     |> put_flash(kind, message)
     |> assign_targets()}
  end

  @impl true
  def handle_info({:site_notice, %{message: message} = notice}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, notice_html(message, notice[:url]))
     |> assign_targets()}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @doc false
  # Public so the type checker does not prune the error clause while
  # `Publishing.deploy/2` is a placeholder that always returns :ok.
  def deploy_flash({:error, :already_deploying}),
    do: {:error, "This deployment target is already being deployed."}

  def deploy_flash({:error, reason}),
    do: {:error, "The deployment could not be started: #{inspect(reason)}"}

  def deploy_flash(_ok), do: {:info, "A deployment was triggered for this deployment target."}

  defp assign_targets(socket) do
    assign(socket, :targets, Publishing.list_targets(socket.assigns.current_scope))
  end

  @doc false
  # The notice as safe HTML: the escaped message and, if there is a URL, a
  # link to it.
  def notice_html(message, nil), do: message

  def notice_html(message, url) do
    assigns = %{message: message, url: url}

    ~H"""
    {@message} <a href={@url} target="_blank" rel="noopener" class="alert-link">{@url}</a>
    """
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> Phoenix.HTML.raw()
  end

  @doc false
  def type_label("staging"), do: "Staging"
  def type_label("production"), do: "Production"
  def type_label("backup"), do: "Backup"
  def type_label(type), do: type
end
