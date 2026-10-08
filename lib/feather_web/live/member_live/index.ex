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
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      preview_path={@site_preview_path}
      active={:users}
    >
      <.header>
        Users
        <:subtitle>The people who can edit {@current_scope.site.title}</:subtitle>
      </.header>

      <div class="settings-page">
        <.list_card id="members">
          <.list_row :for={member <- @members} id={"member-#{member.id}"}>
            <:leading class={[
              "list-row__avatar",
              member.user_id == @current_scope.user.id && "list-row__avatar--primary"
            ]}>
              {initials(member.user.email)}
            </:leading>
            {member.user.email}
            <:trailing :if={member.user_id == @current_scope.user.id}>
              <.neutral_badge>You</.neutral_badge>
            </:trailing>
            <:action
              :if={member.user_id != @current_scope.user.id}
              id={"remove-member-#{member.id}"}
              icon="trash"
              label="Remove"
              click={JS.push("remove_member", value: %{id: member.id})}
              confirm="Are you sure?"
              danger
            />
          </.list_row>
        </.list_card>

        <section class="mt-5 pt-4 border-top">
          <h2 class="section-title">
            Pending invitations
            <span :if={@invitations != []} class="section-title__count">{length(@invitations)}</span>
          </h2>
          <p :if={@invitations == []} id="no-invitations" class="text-body-secondary">
            No pending invitations.
          </p>
          <.list_card :if={@invitations != []} id="invitations">
            <.list_row :for={invitation <- @invitations} id={"invitation-#{invitation.id}"}>
              <:leading class="list-row__avatar"><.icon name="mail" size={16} /></:leading>
              {invitation.email}
              <:meta>Invited {Calendar.strftime(invitation.inserted_at, "%d/%m/%Y")}</:meta>
              <:action
                id={"resend-invitation-#{invitation.id}"}
                icon="send"
                label="Resend"
                click={JS.push("resend_invitation", value: %{id: invitation.id})}
              />
              <:action
                id={"revoke-invitation-#{invitation.id}"}
                icon="x"
                label="Revoke"
                click={JS.push("revoke_invitation", value: %{id: invitation.id})}
                confirm="Are you sure?"
                danger
              />
            </.list_row>
          </.list_card>
        </section>

        <section class="mt-5 pt-4 border-top">
          <h2 class="section-title">Invite someone</h2>
          <p class="text-body-secondary">
            They will receive an email with a link to accept the invitation.
          </p>
          <.form for={@form} id="invitation-form" phx-change="validate" phx-submit="invite">
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              placeholder="john@example.org"
              autocomplete="off"
            />
            <.button variant="primary" phx-disable-with="Sending...">Send invitation</.button>
          </.form>
        </section>
      </div>
    </.site_shell>
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
