defmodule FeatherWeb.DeploymentTargetLive.Form do
  @moduledoc """
  Edits the host name and type of a deployment target. The provider config
  (credentials) is not editable here: it comes from the import or the
  console, as in the Rails app.
  """
  use FeatherWeb, :live_view

  alias Feather.Publishing
  alias Feather.Publishing.DeploymentTarget
  alias FeatherWeb.DeploymentTargetLive.Index

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
      <.header back={index_path(@current_scope)} back_label="Deployments" truncate>
        {@target.public_hostname}
        <:badge>
          <.status_badge id="status-badge">{Index.type_label(@target.type)}</.status_badge>
        </:badge>
      </.header>

      <.form
        for={@form}
        id="deployment-target-form"
        class="form-narrow"
        phx-change="validate"
        phx-submit="save"
      >
        <div class="row g-3">
          <div class="col-12 col-sm-8">
            <.input
              field={@form[:public_hostname]}
              type="text"
              label="Public hostname"
              help="Without https://, for example www.example.org"
              wrapper_class={nil}
            />
          </div>
          <div class="col-12 col-sm-4">
            <.input
              field={@form[:type]}
              type="select"
              label="Type"
              options={@type_options}
              wrapper_class={nil}
            />
          </div>
        </div>
        <.action_bar>
          <.button variant="primary" phx-disable-with="Saving..." id="save-target">Save</.button>
          <.link navigate={index_path(@current_scope)} class="btn btn-light">Cancel</.link>
        </.action_bar>
      </.form>
    </.site_shell>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    target = Publishing.get_target!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Edit deployment target")
     |> assign(:target, target)
     |> assign(
       :type_options,
       Enum.map(DeploymentTarget.types(), &{Index.type_label(&1), &1})
     )
     |> assign(:form, to_form(Publishing.change_target(target)))}
  end

  @impl true
  def handle_event("validate", %{"deployment_target" => params}, socket) do
    changeset = Publishing.change_target(socket.assigns.target, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"deployment_target" => params}, socket) do
    scope = socket.assigns.current_scope

    case Publishing.update_target(scope, socket.assigns.target, params) do
      {:ok, _target} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deployment target was successfully updated.")
         |> push_navigate(to: index_path(scope))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :update))}
    end
  end

  defp index_path(scope), do: ~p"/sites/#{scope.site.public_id}/deployments"
end
