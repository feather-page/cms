defmodule FeatherWeb.UserLive.Settings do
  use FeatherWeb, :live_view

  on_mount {FeatherWeb.UserAuth, :require_sudo_mode}

  alias Feather.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto narrow">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address</:subtitle>
        </.header>

        <.form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input
            field={@email_form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
          />
          <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
        </.form>

        <section id="api-tokens" class="mt-5">
          <h2 class="h5">API tokens</h2>
          <p class="text-body-secondary">Tokens give programs access to the content API as you.</p>

          <div :if={@new_api_token} id="new-api-token" class="alert alert-success">
            <p class="mb-1">Copy your new token now. It will not be shown again.</p>
            <code class="d-block text-break">{@new_api_token}</code>
          </div>

          <ul :if={@api_tokens != []} id="api-token-list" class="list-group mb-3">
            <li
              :for={token <- @api_tokens}
              id={"api-token-#{token.id}"}
              class="list-group-item d-flex align-items-center gap-2"
            >
              <span class="flex-grow-1">
                {token.name || "Unnamed token"}
                <code class="ms-1 text-body-secondary">{token.token_prefix}…</code>
              </span>
              <.button
                id={"delete-api-token-#{token.id}"}
                size="sm"
                variant="danger"
                phx-click={JS.push("delete_api_token", value: %{id: token.id})}
                data-confirm="Are you sure? Programs using this token lose access."
                title="Delete"
                aria-label="Delete"
              >
                <.icon name="trash" size={16} />
              </.button>
            </li>
          </ul>

          <.form for={@api_token_form} id="api_token_form" phx-submit="create_api_token">
            <.input field={@api_token_form[:name]} type="text" label="Name" placeholder="Importer" />
            <.button phx-disable-with="Creating...">Create token</.button>
          </.form>
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
      |> assign(:new_api_token, nil)
      |> assign_api_tokens()

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
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("create_api_token", %{"api_token" => %{"name" => name}}, socket) do
    user = socket.assigns.current_scope.user
    name = if String.trim(name) == "", do: nil, else: String.trim(name)

    case Accounts.create_api_token(user, name) do
      {:ok, plain_token, _api_token} ->
        {:noreply,
         socket
         |> assign(:new_api_token, plain_token)
         |> assign_api_tokens()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The token could not be created.")}
    end
  end

  def handle_event("delete_api_token", %{"id" => id}, socket) do
    :ok = Accounts.delete_api_token(socket.assigns.current_scope.user, id)

    {:noreply,
     socket
     |> assign(:new_api_token, nil)
     |> assign_api_tokens()
     |> put_flash(:info, "The API token was deleted.")}
  end

  defp assign_api_tokens(socket) do
    socket
    |> assign(:api_tokens, Accounts.list_api_tokens(socket.assigns.current_scope.user))
    |> assign(:api_token_form, to_form(%{"name" => ""}, as: :api_token))
  end
end
