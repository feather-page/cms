defmodule FeatherWeb.RedirectLive.Index do
  @moduledoc """
  The redirects of a site: the list, marking temporary and inactive
  redirects, below it the form that adds a redirect or, at
  `/redirects/:id/edit`, edits one, and the form that adds many pasted as
  lines.
  """
  use FeatherWeb, :live_view

  alias Feather.Redirects
  alias Feather.Redirects.Redirect
  alias FeatherWeb.SiteAuth

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      deploy={@site_deploy}
      active={:redirects}
    >
      <.header>
        Redirects
        <:subtitle>Old URLs that lead visitors of {@site.title} on to the right place</:subtitle>
      </.header>

      <div class="max-w-3xl">
        <.empty_state :if={@redirects_empty?} id="no-redirects" icon="signpost">
          No redirects yet. Add one below to send visitors of an old URL to a post, page or project.
        </.empty_state>
        <.list id="redirects" phx-update="stream" class={@redirects_empty? && "hidden"}>
          <.list_row
            :for={{dom_id, row} <- @streams.redirects}
            id={dom_id}
            title={row.redirect.old_path}
            actions_label="Actions"
            menu={:always}
            trailing_on_phone={:meta}
          >
            <:meta>
              <span class="wrap-anywhere">to {row.redirect.target}</span>
              <span :if={row.title}>· {row.title}</span>
            </:meta>
            <:trailing :if={row.redirect.kind == :temporary or not row.active}>
              <.badge :if={row.redirect.kind == :temporary} style={:plain} data-kind="temporary">
                Temporary
              </.badge>
              <.badge :if={not row.active} tone={:warning} data-inactive>Inactive</.badge>
            </:trailing>
            <:action
              id={"edit-redirect-#{row.id}"}
              icon="pencil"
              label="Edit"
              patch={~p"/sites/#{@site.public_id}/redirects/#{row.id}/edit"}
              inline
            />
            <:action
              id={"delete-redirect-#{row.id}"}
              icon="trash-2"
              label="Delete"
              on_click={JS.push("delete", value: %{id: row.id})}
              confirm={"Delete the redirect from #{row.redirect.old_path}?"}
              confirm_text="Visitors of the old path get the site's 404 page after the next deploy."
              confirm_label="Delete"
              danger
            />
          </.list_row>
        </.list>

        <section aria-labelledby="redirect-form-heading" class="mt-8">
          <.section_heading id="redirect-form-heading">
            {if @live_action == :edit, do: "Edit redirect", else: "New redirect"}
          </.section_heading>
          <.form
            for={@form}
            id="redirect-form"
            phx-change="validate"
            phx-submit="save"
            class="max-w-md"
          >
            <.input
              field={@form[:old_path]}
              label="Old path"
              placeholder="/posts/old-post"
              help="A path of this site where no content lives."
              autocomplete="off"
            />
            <.input
              field={@form[:target]}
              label="Target"
              placeholder="/new-post/"
              help="The URL of a post, page or project of this site, or a page like / or /feed.xml."
              autocomplete="off"
            />
            <.input field={@form[:kind]} type="radio_group" label="Kind" options={kind_options()} />
            <.action_bar id="redirect-actions" class="mt-4">
              <.button type="submit" variant={:primary} phx-disable-with="Saving…">
                {if @live_action == :edit, do: "Save redirect", else: "Add redirect"}
              </.button>
              <:secondary :if={@live_action == :edit}>
                <.button id="cancel-edit" patch={~p"/sites/#{@site.public_id}/redirects"}>
                  Cancel
                </.button>
              </:secondary>
            </.action_bar>
          </.form>
        </section>

        <section aria-labelledby="paste-redirects-heading" class="mt-8">
          <.section_heading id="paste-redirects-heading">Paste redirects</.section_heading>
          <.form
            for={@paste_form}
            id="paste-redirects-form"
            phx-change="change_paste"
            phx-submit="paste"
            class="max-w-md"
          >
            <.input
              field={@paste_form[:lines]}
              type="textarea"
              label="Redirects"
              rows="6"
              placeholder="/posts/old-post /new-post/"
              help="One per line: the old path, a space and the target. All are permanent."
              autocomplete="off"
            />
            <.alert
              :if={@paste_errors != []}
              id="paste-errors"
              tone={:error}
              title={lines_not_added(length(@paste_errors))}
              class="mt-4"
            >
              <ul class="space-y-1">
                <li :for={{line, messages} <- @paste_errors}>
                  <code class="wrap-anywhere">{line}</code>
                  <span class="block">{Enum.join(messages, ". ")}</span>
                </li>
              </ul>
            </.alert>
            <.action_bar id="paste-redirects-actions" class="mt-4">
              <.button type="submit" phx-disable-with="Adding…">Add redirects</.button>
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
     |> assign(:page_title, "Redirects")
     |> assign(:site, socket.assigns.current_scope.site)
     |> assign_paste([])
     |> assign_redirects()}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, %{assigns: %{live_action: :edit}} = socket) do
    redirect = Redirects.get_redirect!(socket.assigns.current_scope, id)
    {:noreply, assign_form(socket, redirect, %{})}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, assign_form(socket, %Redirect{}, %{})}
  end

  @impl true
  def handle_event("validate", %{"redirect" => params}, socket) do
    {:noreply, assign_form(socket, socket.assigns.redirect, params, :validate)}
  end

  def handle_event("save", %{"redirect" => params}, socket) do
    scope = socket.assigns.current_scope

    case save(scope, socket.assigns.redirect, params) do
      {:ok, message} ->
        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign_redirects()
         |> SiteAuth.refresh_deploy_status()
         |> push_patch(to: ~p"/sites/#{socket.assigns.site.public_id}/redirects")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}

      {:error, :stale} ->
        {:noreply,
         socket
         |> put_flash(:error, "This redirect no longer exists.")
         |> assign_redirects()
         |> push_patch(to: ~p"/sites/#{socket.assigns.site.public_id}/redirects")}
    end
  end

  def handle_event("change_paste", %{"paste" => params}, socket),
    do: {:noreply, assign(socket, :paste_form, to_form(params, as: :paste))}

  def handle_event("paste", %{"paste" => %{"lines" => lines}}, socket) do
    {created, failed} =
      socket.assigns.current_scope
      |> Redirects.create_redirects(lines)
      |> Enum.split_with(&match?({_line, {:ok, _redirect}}, &1))

    socket =
      if created == [] do
        socket
      else
        socket
        |> put_flash(:info, redirects_created(length(created)))
        |> SiteAuth.refresh_deploy_status()
      end

    {:noreply, socket |> assign_paste(failed) |> assign_redirects()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with %Redirect{} = redirect <- Redirects.get_redirect(scope, id),
           {:ok, _} <- Redirects.delete_redirect(scope, redirect) do
        socket
        |> put_flash(:info, "Redirect was successfully deleted.")
        |> SiteAuth.refresh_deploy_status()
        |> leave_deleted_form(redirect)
      else
        _gone -> put_flash(socket, :error, "This redirect no longer exists.")
      end

    {:noreply, assign_redirects(socket)}
  end

  defp save(scope, %Redirect{id: nil}, params) do
    with {:ok, _} <- Redirects.create_redirect(scope, params),
         do: {:ok, "Redirect was successfully created."}
  end

  defp save(scope, redirect, params) do
    with {:ok, _} <- Redirects.update_redirect(scope, redirect, params),
         do: {:ok, "Redirect was successfully updated."}
  end

  defp leave_deleted_form(%{assigns: %{redirect: %{id: id}}} = socket, %Redirect{id: id}),
    do: push_patch(socket, to: ~p"/sites/#{socket.assigns.site.public_id}/redirects")

  defp leave_deleted_form(socket, _deleted), do: socket

  defp assign_redirects(socket) do
    scope = socket.assigns.current_scope

    rows =
      for redirect <- Redirects.list_redirects(scope) do
        %{
          id: redirect.public_id,
          redirect: redirect,
          title: target_title(redirect),
          active: Redirects.active?(scope, redirect)
        }
      end

    socket
    |> assign(:redirects_empty?, rows == [])
    |> stream(:redirects, rows, reset: true)
  end

  defp assign_form(socket, redirect, params, action \\ nil) do
    changeset = Redirects.change_redirect(socket.assigns.current_scope, redirect, params)

    socket
    |> assign(:redirect, redirect)
    |> assign(:form, to_form(changeset, action: action))
  end

  defp assign_paste(socket, failed) do
    lines = Enum.map_join(failed, "\n", &elem(&1, 0))

    socket
    |> assign(:paste_form, to_form(%{"lines" => lines}, as: :paste))
    |> assign(
      :paste_errors,
      Enum.map(failed, fn {line, {:error, changeset}} -> {line, messages(changeset)} end)
    )
  end

  defp messages(changeset) do
    for {field, errors} <- Ecto.Changeset.traverse_errors(changeset, &translate_error/1),
        error <- errors,
        do: "#{Phoenix.Naming.humanize(field)} #{error}"
  end

  defp redirects_created(1), do: "1 redirect was created."
  defp redirects_created(count), do: "#{count} redirects were created."

  defp lines_not_added(1), do: "1 line was not added"
  defp lines_not_added(count), do: "#{count} lines were not added"

  defp kind_options, do: [{"Permanent (301)", "permanent"}, {"Temporary (302)", "temporary"}]

  defp target_title(redirect) do
    case Redirect.target_record(redirect) do
      nil -> nil
      record -> record.title
    end
  end
end
