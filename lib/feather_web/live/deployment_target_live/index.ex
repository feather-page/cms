defmodule FeatherWeb.DeploymentTargetLive.Index do
  @moduledoc """
  The deployment targets of a site, with a button to deploy each.

  While a target deploys, a section above the list shows its steps
  (`Feather.Publishing.deploy_steps/0`) and how long it has been running.
  The pipeline broadcasts `{:deploy_progress, progress}` at every step and
  `{:site_notice, notice}` when it finishes; the site shell shows the
  notice (see `FeatherWeb.SiteAuth`), and this page receives both
  (`forward_site_notices`) to update the steps and the list.
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
      deploy={@site_deploy}
      active={:deployments}
    >
      <.header>
        Deployments
        <:subtitle>Where {@current_scope.site.title} is published</:subtitle>
      </.header>

      <section
        :for={target <- @targets}
        :if={@progress[target.public_id]}
        id={"deploy-progress-#{target.public_id}"}
        class="mb-6 rounded-box border border-base-content/10 p-4"
        aria-live="polite"
      >
        <div class="flex items-center justify-between gap-4">
          <h2 class="font-semibold wrap-anywhere">Deploying to {target.public_hostname}</h2>
          <span
            id={"deploy-elapsed-#{target.public_id}"}
            phx-hook=".Elapsed"
            phx-update="ignore"
            data-started-at={DateTime.to_iso8601(@progress[target.public_id].started_at)}
            class="text-sm tabular-nums text-base-content/70"
          ></span>
        </div>
        <ol class="mt-3 grid gap-2 text-sm">
          <li
            :for={{step, state} <- steps(@progress[target.public_id].step)}
            data-step={step}
            data-state={state}
            class={["flex items-center gap-2", state == :current && "font-medium"]}
          >
            <.icon :if={state == :done} name="circle-check" class="size-5 text-success-ink" />
            <span :if={state == :current} class="loading loading-spinner loading-sm text-primary"></span>
            <.icon :if={state == :pending} name="circle" class="size-5 text-base-content/30" />
            <span class={state == :pending && "text-base-content/70"}>
              {step_label(step, target)}
            </span>
          </li>
        </ol>
        <p class="mt-3 text-sm text-base-content/70">
          You can leave this page; the deploy keeps running.
        </p>
      </section>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".Elapsed">
        export default {
          mounted() {
            const start = Date.parse(this.el.dataset.startedAt)
            const tick = () => {
              const s = Math.max(0, Math.floor((Date.now() - start) / 1000))
              this.el.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
            }
            tick()
            this.timer = setInterval(tick, 1000)
          },
          destroyed() { clearInterval(this.timer) }
        }
      </script>

      <.empty_state :if={@targets == []} id="no-deployment-targets" icon="globe">
        No deployment targets configured.
      </.empty_state>

      <.list :if={@targets != []} id="deployment-targets">
        <.list_row
          :for={target <- @targets}
          id={"target-#{target.public_id}"}
          navigate={~p"/sites/#{@current_scope.site.public_id}/deployments/#{target.public_id}/edit"}
          title={target.public_hostname}
        >
          <:leading><.tile icon="globe" /></:leading>
          <:meta>
            <span class="target-provider">{provider_label(target.provider)}</span>
            · <span class="target-deployed">{deployed_label(target.last_deployed_at)}</span>
          </:meta>
          <:trailing>
            <.badge :if={target.deploying} id={"deploying-#{target.public_id}"}>
              <span class="loading loading-spinner loading-xs"></span> Deploying
            </.badge>
            <.button
              id={"deploy-#{target.public_id}"}
              size={:sm}
              icon="rocket"
              class="relative z-10"
              phx-click={JS.push("deploy", value: %{id: target.public_id})}
              disabled={target.deploying}
            >
              Deploy
            </.button>
          </:trailing>
        </.list_row>
      </.list>
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
    {:noreply, assign_targets(socket)}
  end

  @impl true
  def handle_info({:site_notice, _notice}, socket) do
    {:noreply, assign_targets(socket)}
  end

  def handle_info({:deploy_progress, %{target_id: id} = progress}, socket) do
    {:noreply, update(socket, :progress, &Map.put(&1, id, progress))}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # The progress of running deploys, by target public id: after a reload
  # from the registry, then from the broadcasts. A deploy requested here
  # shows up with its first step.
  defp assign_targets(socket) do
    targets = Publishing.list_targets(socket.assigns.current_scope)

    assign(socket, targets: targets, progress: Publishing.deploy_progress_by_target(targets))
  end

  defp steps(current) do
    shown =
      if current == :waiting,
        do: Publishing.deploy_steps(),
        else: Publishing.deploy_steps() -- [:waiting]

    index = Enum.find_index(shown, &(&1 == current))

    shown
    |> Enum.with_index()
    |> Enum.map(fn {step, i} ->
      {step,
       cond do
         i < index -> :done
         i == index -> :current
         true -> :pending
       end}
    end)
  end

  defp step_label(step, target) do
    label = Publishing.deploy_step_label(step, :checklist)
    if step == :upload, do: "#{label} to #{provider_label(target.provider)}", else: label
  end

  @doc ~s(When the target was last deployed, e.g. "Deployed 3 days ago".)
  def deployed_label(nil), do: "Never deployed"
  def deployed_label(at), do: "Deployed #{FeatherWeb.SiteComponents.time_ago(at)}"

  @doc "The name of a provider for people, e.g. `Hetzner (FTPS)`."
  def provider_label("hetzner_ftps"), do: "Hetzner (FTPS)"
  def provider_label(provider), do: provider
end
