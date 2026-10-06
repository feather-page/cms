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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Edit deployment target
        <:subtitle>{@target.public_hostname}</:subtitle>
      </.header>

      <.form for={@form} id="deployment-target-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:public_hostname]} type="text" label="Public hostname" />
        <.input field={@form[:type]} type="select" label="Type" options={@type_options} />
        <div class="d-flex gap-2">
          <.button variant="primary" phx-disable-with="Saving...">
            Update deployment target
          </.button>
          <.button navigate={index_path(@current_scope)}>Cancel</.button>
        </div>
      </.form>
    </Layouts.app>
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
