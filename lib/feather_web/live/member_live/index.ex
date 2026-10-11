defmodule FeatherWeb.MemberLive.Index do
  @moduledoc """
  The users of a site: its members (who can be removed, except oneself),
  the pending invitations (resend, revoke) and a form to invite someone by
  email.
  """
  use FeatherWeb, :live_view

  alias Feather.Sites
  alias Feather.Sites.{Invitation, SiteUser}

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      preview_path={@site_preview_path}
      active={:users}
    >
      <.header>
        Users
        <:subtitle>The people who can edit {@current_scope.site.title}</:subtitle>
      </.header>

      <div class="max-w-3xl">
        <.list id="members">
          <.list_row
            :for={member <- @members}
            id={"member-#{member.id}"}
            title={member.user.email}
            actions_label="Actions"
            menu={:always}
          >
            <:leading>
              <.avatar
                initials={initials(member.user.email)}
                shape={:round}
                tone={if member.user_id == @current_scope.user.id, do: :primary, else: :base}
              />
            </:leading>
            <:trailing :if={member.user_id == @current_scope.user.id}>
              <.badge style={:plain}>You</.badge>
            </:trailing>
            <:action
              :if={member.user_id != @current_scope.user.id}
              id={"remove-member-#{member.id}"}
              icon="trash-2"
              label="Remove"
              on_click={JS.push("remove_member", value: %{id: member.id})}
              confirm={"Remove #{member.user.email} from this site?"}
              confirm_text="They lose access to the site at once. You can invite them again."
              confirm_label="Remove"
              danger
            />
          </.list_row>
        </.list>

        <section aria-labelledby="invitations-heading" class="mt-8">
          <.section_heading
            id="invitations-heading"
            count={if @invitations != [], do: length(@invitations)}
          >
            Pending invitations
          </.section_heading>
          <.empty_state :if={@invitations == []} id="no-invitations" icon="mail">
            No pending invitations.
          </.empty_state>
          <.list :if={@invitations != []} id="invitations">
            <.list_row
              :for={invitation <- @invitations}
              id={"invitation-#{invitation.id}"}
              title={invitation.email}
              actions_label="Actions"
              menu={:always}
            >
              <:leading><.avatar icon="mail" shape={:round} tone={:base} /></:leading>
              <:meta>Invited {Calendar.strftime(invitation.inserted_at, "%d/%m/%Y")}</:meta>
              <:action
                id={"resend-invitation-#{invitation.id}"}
                icon="send"
                label="Resend"
                on_click={JS.push("resend_invitation", value: %{id: invitation.id})}
              />
              <:action
                id={"revoke-invitation-#{invitation.id}"}
                icon="x"
                label="Revoke"
                on_click={JS.push("revoke_invitation", value: %{id: invitation.id})}
                confirm={"Revoke the invitation for #{invitation.email}?"}
                confirm_text="The link in the email stops working."
                confirm_label="Revoke"
                danger
              />
            </.list_row>
          </.list>
        </section>

        <section aria-labelledby="invite-heading" class="mt-8">
          <.section_heading id="invite-heading">Invite someone</.section_heading>
          <p class="text-sm text-base-content/70">
            They will receive an email with a link to accept the invitation.
          </p>
          <.form
            for={@form}
            id="invitation-form"
            phx-change="validate"
            phx-submit="invite"
            class="max-w-md"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              placeholder="john@example.org"
              autocomplete="off"
            />
            <.action_bar id="invitation-actions" class="mt-4">
              <.button type="submit" variant={:primary} phx-disable-with="Sending…">
                Send invitation
              </.button>
            </.action_bar>
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

    socket =
      with %Invitation{} = invitation <- Sites.get_invitation(scope, id),
           {:ok, _invitation} <- Sites.resend_invitation(scope, invitation, &accept_url/1) do
        put_flash(socket, :info, "Invitation was successfully resent.")
      else
        nil ->
          put_flash(socket, :error, "This invitation no longer exists.")

        {:error, :already_accepted} ->
          put_flash(socket, :error, "The invitation has already been accepted.")
      end

    {:noreply, assign_lists(socket)}
  end

  def handle_event("revoke_invitation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with %Invitation{} = invitation <- Sites.get_invitation(scope, id),
           {:ok, _} <- Sites.delete_invitation(scope, invitation) do
        put_flash(socket, :info, "Invitation was successfully revoked.")
      else
        nil -> put_flash(socket, :error, "This invitation no longer exists.")
        {:error, _reason} -> put_flash(socket, :error, "The invitation could not be revoked.")
      end

    {:noreply, assign_lists(socket)}
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with %SiteUser{} = member <- Sites.get_member(scope, id),
           {:ok, _} <- Sites.remove_member(scope, member) do
        put_flash(socket, :info, "The user was successfully removed from the site.")
      else
        nil ->
          put_flash(socket, :error, "This user is no longer a member of the site.")

        {:error, :cannot_remove_self} ->
          put_flash(socket, :error, "You cannot remove yourself from the site.")

        {:error, _reason} ->
          put_flash(socket, :error, "The user could not be removed from the site.")
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
