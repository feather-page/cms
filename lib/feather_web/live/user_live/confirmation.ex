defmodule FeatherWeb.UserLive.Confirmation do
  use FeatherWeb, :live_view

  alias Feather.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto narrow">
        <.header class="text-center">Welcome {@user.email}</.header>

        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <div class="d-grid gap-2">
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Confirming..."
              variant="primary"
            >
              Confirm and stay logged in
            </.button>
            <.button phx-disable-with="Confirming...">
              Confirm and log in only this time
            </.button>
          </div>
        </.form>

        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <div class="d-grid gap-2">
            <%= if @current_scope do %>
              <.button phx-disable-with="Logging in..." variant="primary">
                Log in
              </.button>
            <% else %>
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Logging in..."
                variant="primary"
              >
                Keep me logged in on this device
              </.button>
              <.button phx-disable-with="Logging in...">
                Log me in only this time
              </.button>
            <% end %>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
