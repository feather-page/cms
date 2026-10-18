defmodule FeatherWeb.DeploymentTargetLive.Index do
  @moduledoc """
  The deployment target of a site, with a button to deploy the site.

  While the site deploys, a section above the target shows the steps
  (`Feather.Publishing.deploy_steps/0`) and how long the deploy has been
  running. Target and progress come from the shell's `site_deploy` (see
  `FeatherWeb.SiteAuth`), which follows the pipeline's broadcasts.
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
        <:actions :if={@site_deploy.target}>
          <.button
            id="deploy-target"
            icon="rocket"
            phx-click="deploy_site"
            disabled={@site_deploy.target.deploying}
          >
            Deploy
          </.button>
        </:actions>
      </.header>

      <section
        :if={@site_deploy.progress}
        id="deploy-progress"
        class="mb-6 rounded-box border border-base-content/10 p-4"
        aria-live="polite"
      >
        <div class="flex items-center justify-between gap-4">
          <h2 class="font-semibold wrap-anywhere">Deploying to {@current_scope.site.domain}</h2>
          <span
            id="deploy-elapsed"
            phx-hook=".Elapsed"
            phx-update="ignore"
            data-started-at={DateTime.to_iso8601(@site_deploy.progress.started_at)}
            class="text-sm tabular-nums text-base-content/70"
          ></span>
        </div>
        <ol class="mt-3 grid gap-2 text-sm">
          <li
            :for={{step, state} <- steps(@site_deploy.progress.step)}
            data-step={step}
            data-state={state}
            class={["flex items-center gap-2", state == :current && "font-medium"]}
          >
            <.icon :if={state == :done} name="circle-check" class="size-5 text-success-ink" />
            <span :if={state == :current} class="loading loading-spinner loading-sm text-primary"></span>
            <.icon :if={state == :pending} name="circle" class="size-5 text-base-content/30" />
            <span class={state == :pending && "text-base-content/70"}>
              {step_label(step, @site_deploy.target)}
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

      <.empty_state :if={!@site_deploy.target} id="no-deployment-target" icon="globe">
        No deployment target configured.
      </.empty_state>

      <.description_list :if={@site_deploy.target} id="deployment-target" class="max-w-3xl">
        <:item label="Address">
          <a
            href={"https://#{@current_scope.site.domain}"}
            target="_blank"
            rel="noopener"
            class="link link-hover"
          >
            {@current_scope.site.domain}
          </a>
        </:item>
        <:item label="Provider">
          <span id="target-provider">{provider_label(@site_deploy.target.provider)}</span>
        </:item>
        <:item label="Last deploy">
          <span id="target-deployed" class="inline-flex items-center gap-2">
            <.badge :if={@site_deploy.target.deploying} id="target-deploying">
              <span class="loading loading-spinner loading-xs"></span> Deploying
            </.badge>
            {deployed_label(@site_deploy.target.last_deployed_at)}
          </span>
        </:item>
      </.description_list>
    </.site_shell>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Deployments")}
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
    if step == :upload, do: "#{label} via #{provider_label(target.provider)}", else: label
  end

  defp deployed_label(nil), do: "Never deployed"
  defp deployed_label(at), do: "Deployed #{FeatherWeb.SiteComponents.time_ago(at)}"

  defp provider_label("ftps"), do: "FTPS"
  defp provider_label(provider), do: provider
end
