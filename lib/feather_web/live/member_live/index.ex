defmodule FeatherWeb.MemberLive.Index do
  @moduledoc """
  The users of a site: its members (who can be removed, except oneself),
  the pending invitations (resend, revoke) and a form to invite someone by
  email.
  """
  use FeatherWeb, :live_view

  alias Feather.Sites
  alias Feather.Sites.Invitation

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Users
        <:subtitle>The people who can edit {@current_scope.site.title}</:subtitle>
      </.header>

      <ul id="members" class="list-group mb-5">
        <li
          :for={member <- @members}
          id={"member-#{member.id}"}
          class="list-group-item d-flex align-items-center gap-2"
        >
          <.icon name="user" />
          <span class="flex-grow-1">{member.user.email}</span>
          <.button
            :if={member.user_id != @current_scope.user.id}
            id={"remove-member-#{member.id}"}
            size="sm"
            variant="danger"
            phx-click={JS.push("remove_member", value: %{id: member.id})}
            data-confirm="Are you sure?"
            title="Remove"
            aria-label="Remove"
          >
            <.icon name="trash" size={16} />
          </.button>
        </li>
      </ul>

      <h2 class="h5 mb-3">Invite another user</h2>
      <p class="text-body-secondary">
        Enter the email address of the user you want to invite.
        They will receive an email with a link to accept the invitation.
      </p>
      <.form
        for={@form}
        id="invitation-form"
        phx-change="validate"
        phx-submit="invite"
        class="mb-5"
      >
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          placeholder="john@example.org"
          autocomplete="off"
        />
        <.button variant="primary" phx-disable-with="Sending...">Send invitation</.button>
      </.form>

      <h2 class="h5 mb-3">Pending invitations</h2>
      <p :if={@invitations == []} id="no-invitations" class="text-body-secondary">
        Currently there are no pending invitations.
      </p>
      <.table
        :if={@invitations != []}
        id="invitations"
        rows={@invitations}
        row_id={&"invitation-#{&1.id}"}
      >
        <:col :let={invitation} label="Email">{invitation.email}</:col>
        <:action :let={invitation}>
          <.button
            id={"resend-invitation-#{invitation.id}"}
            size="sm"
            phx-click={JS.push("resend_invitation", value: %{id: invitation.id})}
          >
            Resend
          </.button>
          <.button
            id={"revoke-invitation-#{invitation.id}"}
            size="sm"
            variant="danger"
            phx-click={JS.push("revoke_invitation", value: %{id: invitation.id})}
            data-confirm="Are you sure?"
          >
            Revoke
          </.button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign_lists()
     |> assign_form(%{})}
  end

  @impl true
  def handle_event("validate", %{"invitation" => params}, socket) do
    {:noreply, assign_form(socket, params, :validate)}
  end

  def handle_event("invite", %{"invitation" => params}, socket) do
    scope = socket.assigns.current_scope

    case Sites.create_invitation(scope, params) do
      {:ok, invitation} ->
        {:ok, _email} = Sites.deliver_invitation(invitation, &accept_url/1)

        {:noreply,
         socket
         |> assign_lists()
         |> assign_form(%{})
         |> put_flash(:info, "User was successfully invited.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("resend_invitation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    invitation = Sites.get_invitation!(scope, id)

    socket =
      case Sites.resend_invitation(scope, invitation, &accept_url/1) do
        {:ok, _invitation} ->
          put_flash(socket, :info, "Invitation was successfully resent.")

        {:error, :already_accepted} ->
          put_flash(socket, :error, "The invitation has already been accepted.")
      end

    {:noreply, assign_lists(socket)}
  end

  def handle_event("revoke_invitation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    invitation = Sites.get_invitation!(scope, id)
    {:ok, _} = Sites.delete_invitation(scope, invitation)

    {:noreply,
     socket
     |> assign_lists()
     |> put_flash(:info, "Invitation was successfully revoked.")}
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    member = Sites.get_member!(scope, id)

    socket =
      case Sites.remove_member(scope, member) do
        {:ok, _} ->
          put_flash(socket, :info, "The user was successfully removed from the site.")

        {:error, :cannot_remove_self} ->
          put_flash(socket, :error, "You cannot remove yourself from the site.")
      end

    {:noreply, assign_lists(socket)}
  end

  defp accept_url(token), do: url(~p"/invitations/#{token}")

  defp assign_lists(socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:members, Sites.list_members(scope))
    |> assign(:invitations, Sites.list_pending_invitations(scope))
  end

  defp assign_form(socket, params, action \\ nil) do
    changeset = Sites.change_invitation(%Invitation{}, params)
    assign(socket, :form, to_form(changeset, action: action))
  end
end
