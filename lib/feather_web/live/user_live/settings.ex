defmodule FeatherWeb.UserLive.Settings do
  use FeatherWeb, :live_view

  on_mount {FeatherWeb.UserAuth, :require_sudo_mode}

  alias Feather.{Accounts, OAuth}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Account settings
        <:subtitle>Your email address and connected apps</:subtitle>
      </.header>

      <div class="max-w-3xl">
        <.section_heading id="email-heading">Email address</.section_heading>
        <.form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
          class="max-w-md"
        >
          <.input
            field={@email_form[:email]}
            type="email"
            label="Email"
            hide_label
            autocomplete="username"
            spellcheck="false"
            required
          />
          <.action_bar id="email-actions" class="mt-4">
            <.button type="submit" variant={:primary} phx-disable-with="Changing…">
              Change email
            </.button>
          </.action_bar>
        </.form>

        <section id="connected-apps" aria-labelledby="connected-apps-heading" class="mt-8">
          <.section_heading id="connected-apps-heading">Connected apps</.section_heading>
          <p class="text-sm text-base-content/70">
            Apps such as Claude that you allowed to work on your sites as you.
            An app unused for 90 days loses access.
          </p>

          <p
            :if={@connected_apps == []}
            id="no-connected-apps"
            class="mt-4 text-sm text-base-content/70"
          >
            No connected apps.
          </p>

          <.list :if={@connected_apps != []} id="connected-app-list" class="mt-4">
            <.list_row
              :for={app <- @connected_apps}
              id={"connected-app-#{app.id}"}
              title={app.client_name}
              actions_label="Actions"
              menu={:always}
            >
              <:leading><.tile icon="bot" /></:leading>
              <:meta>
                Connected {format_date(app.inserted_at)} · Last used {format_date(app.last_used_at)}
              </:meta>
              <:action
                id={"revoke-connected-app-#{app.id}"}
                icon="unplug"
                label="Revoke"
                on_click={JS.push("revoke_connected_app", value: %{id: app.id})}
                confirm={"Revoke access for “#{app.client_name}”?"}
                confirm_text="The app can no longer work on your sites. To use it again, connect it anew."
                confirm_label="Revoke"
                danger
              />
            </.list_row>
          </.list>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign_connected_apps()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, put_flash(socket, :info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("revoke_connected_app", %{"id" => id}, socket) do
    :ok = OAuth.revoke_connected_app(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> assign_connected_apps()
     |> put_flash(:info, "The app no longer has access.")}
  end

  defp assign_connected_apps(socket) do
    assign(socket, :connected_apps, OAuth.list_connected_apps(socket.assigns.current_scope))
  end

  defp format_date(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y")
end
