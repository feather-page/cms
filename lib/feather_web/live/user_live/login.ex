defmodule FeatherWeb.UserLive.Login do
  use FeatherWeb, :live_view

  alias Feather.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} bare>
      <div class="mx-auto max-w-md">
        <div class="mb-8 flex flex-col items-center text-center">
          <.plush name="feather" size={:xxl} />
          <h1 class="mt-4 text-2xl font-semibold">
            {if @sent_to, do: "Check your email", else: "Log in to Feather"}
          </h1>
          <p :if={!@sent_to} class="mt-1 text-sm text-base-content/70">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              We will email you a link to log in. There is no password.
            <% end %>
          </p>
          <p :if={@sent_to} id="login-sent" class="mt-1 text-sm text-base-content/70">
            If <span class="font-medium text-base-content">{@sent_to}</span>
            has an account, a link to log in is on its way.
          </p>
        </div>

        <.alert :if={local_mail_adapter?()} tone={:info} class="mb-4">
          You are running the local mail adapter.
          To see sent emails, visit <.link href="/dev/mailbox" class="link">the mailbox page</.link>.
        </.alert>

        <div :if={@sent_to} class="text-center">
          <.button id="use-another-email" variant={:ghost} phx-click="use_another_email">
            Use another email
          </.button>
        </div>

        <.form
          :let={f}
          :if={!@sent_to}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button
            type="submit"
            variant={:primary}
            class="mt-4 w-full"
            phx-disable-with="Sending…"
          >
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email) || current_email(socket)
    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, sent_to: nil)}
  end

  @impl true
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    email = email |> String.trim() |> String.downcase()

    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    {:noreply, assign(socket, :sent_to, email)}
  end

  # Reauthenticating keeps the (read-only) email of the logged-in user.
  def handle_event("use_another_email", _params, socket) do
    form = to_form(%{"email" => current_email(socket)}, as: "user")
    {:noreply, assign(socket, sent_to: nil, form: form)}
  end

  defp current_email(socket),
    do: get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

  defp local_mail_adapter? do
    Application.get_env(:feather, Feather.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
