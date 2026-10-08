defmodule FeatherWeb.SiteLive.Settings do
  @moduledoc """
  The settings of a site: emoji, title, domain, language and copyright
  notice, and the site's social media links.

  Saving the site or changing its links publishes the staging targets
  (`Feather.Publishing.publish_site/1`), like Rails did.
  """
  use FeatherWeb, :live_view

  alias Feather.Accounts.Scope
  alias Feather.{Publishing, Sites}
  alias Feather.Sites.{Languages, SocialMediaLink, SocialMediaService}

  @impl true
  def render(assigns) do
    ~H"""
    <.site_shell
      flash={@flash}
      current_scope={@current_scope}
      notices={@site_notices}
      preview_path={@site_preview_path}
      active={:settings}
    >
      <.header>
        Site settings
        <:subtitle>{@current_scope.site.title}</:subtitle>
      </.header>

      <div class="settings-page">
        <.form for={@form} id="site-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:title]} type="text" label="Title" placeholder="Timon's Blog" />
          <div class="row gx-3">
            <div class="col-12 col-sm-2">
              <.input field={@form[:emoji]} type="text" label="Emoji" />
            </div>
            <div class="col-12 col-sm">
              <.input field={@form[:domain]} type="text" label="Domain" placeholder="timon.blog" />
            </div>
            <div class="col-12 col-sm-4">
              <.input
                field={@form[:language_code]}
                type="select"
                label="Language"
                options={Languages.options()}
              />
            </div>
          </div>
          <.input
            field={@form[:copyright]}
            type="text"
            label="Copyright notice"
            help="The copyright notice in the footer of your site. {{CurrentYear}} is replaced with the current year."
          />
          <div class="d-flex gap-2">
            <.button variant="primary" phx-disable-with="Saving...">Save</.button>
            <.link
              navigate={~p"/sites/#{@current_scope.site.public_id}/posts"}
              class="btn btn-light"
            >
              Cancel
            </.link>
          </div>
        </.form>

        <section id="social-media" class="mt-5 pt-4 border-top">
          <h2 class="section-title">Social media links</h2>
          <p :if={@links_empty?} id="no-social-media-links" class="text-body-secondary">
            Add links to your social profiles. They are shown in the footer of your site.
          </p>

          <.list_card id="social-media-links" stream hidden={@links_empty?} class="mb-3">
            <.list_row :for={{id, link} <- @streams.social_media_links} id={id}>
              <:leading><.icon name={link.icon} /></:leading>
              {link.name}
              <:meta>
                <a href={link.url} target="_blank" rel="noopener" class="link-secondary">
                  {link.url}
                </a>
              </:meta>
              <:action
                id={"delete-#{id}"}
                icon="trash"
                label="Delete"
                click={JS.push("delete_link", value: %{id: link.id})}
                confirm="Are you sure?"
                danger
              />
            </.list_row>
          </.list_card>

          <button
            :if={!@adding_link?}
            type="button"
            id="add-link"
            class="btn btn-light"
            phx-click="add_link"
          >
            <.icon name="plus" size={16} /> Add link
          </button>

          <div :if={@adding_link?} class="card">
            <div class="card-body">
              <.form
                for={@link_form}
                id="social-media-link-form"
                phx-change="validate_link"
                phx-submit="save_link"
              >
                <fieldset class="mb-3">
                  <legend class="form-label">Service</legend>
                  <div id="social-media-services" class="d-flex flex-wrap gap-2">
                    <button
                      :for={service <- @services}
                      type="button"
                      id={"service-#{service.icon}"}
                      class={[
                        "btn btn-light service-tile",
                        @link_form[:icon].value == service.icon && "active"
                      ]}
                      title={service.name}
                      aria-label={service.name}
                      aria-pressed={to_string(@link_form[:icon].value == service.icon)}
                      phx-click={JS.push("pick_service", value: %{icon: service.icon})}
                    >
                      <.icon name={service.icon} />
                    </button>
                  </div>
                  <.input field={@link_form[:icon]} type="hidden" />
                  <p
                    :for={msg <- link_icon_errors(@link_form)}
                    class="text-danger small mt-1 mb-0"
                    id="social-media-link-icon-error"
                  >
                    {msg}
                  </p>
                </fieldset>
                <div class="row gx-3">
                  <div class="col-12 col-sm-4">
                    <.input
                      field={@link_form[:name]}
                      type="text"
                      label="Name"
                      placeholder="Mastodon"
                    />
                  </div>
                  <div class="col-12 col-sm-8">
                    <.input
                      field={@link_form[:url]}
                      type="url"
                      label="URL"
                      placeholder={@url_placeholder}
                    />
                  </div>
                </div>
                <div class="d-flex gap-2">
                  <button type="submit" class="btn btn-light" phx-disable-with="Saving...">
                    Add link
                  </button>
                  <button
                    type="button"
                    id="cancel-link"
                    class="btn btn-light"
                    phx-click="cancel_link"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </section>
      </div>
    </.site_shell>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    links = Sites.list_social_media_links(scope)

    {:ok,
     socket
     |> assign(:page_title, "Site settings")
     |> assign(:services, SocialMediaService.all())
     |> assign(:form, to_form(Sites.change_site(scope.site)))
     |> assign(:links_empty?, links == [])
     |> stream(:social_media_links, links)
     |> reset_link_form()}
  end

  ## Site form

  @impl true
  def handle_event("validate", %{"site" => params}, socket) do
    changeset = Sites.change_site(socket.assigns.current_scope.site, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"site" => params}, socket) do
    scope = socket.assigns.current_scope

    case Sites.update_site(scope, scope.site, params) do
      {:ok, site} ->
        scope = Scope.put_site(scope, site)
        Publishing.publish_site(scope)

        {:noreply,
         socket
         |> assign(:current_scope, scope)
         |> assign(:form, to_form(Sites.change_site(site)))
         |> put_flash(:info, "Site was successfully updated.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :update))}
    end
  end

  ## Social media links

  def handle_event("add_link", _params, socket) do
    {:noreply, assign(socket, :adding_link?, true)}
  end

  def handle_event("cancel_link", _params, socket) do
    {:noreply, reset_link_form(socket)}
  end

  def handle_event("pick_service", %{"icon" => icon}, socket) do
    case SocialMediaService.find(icon) do
      nil ->
        {:noreply, socket}

      service ->
        params =
          socket.assigns.link_params
          |> Map.put("icon", service.icon)
          |> Map.put("name", service.name)

        {:noreply,
         socket
         |> assign(:url_placeholder, service.url_placeholder)
         |> assign_link_form(params)}
    end
  end

  def handle_event("validate_link", %{"social_media_link" => params}, socket) do
    {:noreply, assign_link_form(socket, params, :validate)}
  end

  def handle_event("save_link", %{"social_media_link" => params}, socket) do
    scope = socket.assigns.current_scope

    case Sites.create_social_media_link(scope, params) do
      {:ok, link} ->
        Publishing.publish_site(scope)

        {:noreply,
         socket
         |> stream_insert(:social_media_links, link)
         |> assign(:links_empty?, false)
         |> reset_link_form()
         |> put_flash(:info, "Social media link was successfully created.")}

      {:error, _changeset} ->
        {:noreply, assign_link_form(socket, params, :insert)}
    end
  end

  def handle_event("delete_link", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    link = Sites.get_social_media_link!(scope, id)
    {:ok, _} = Sites.delete_social_media_link(scope, link)
    Publishing.publish_site(scope)

    {:noreply,
     socket
     |> stream_delete(:social_media_links, link)
     |> assign(:links_empty?, Sites.list_social_media_links(scope) == [])
     |> put_flash(:info, "Social media link was successfully deleted.")}
  end

  defp reset_link_form(socket) do
    socket
    |> assign(:adding_link?, false)
    |> assign(:url_placeholder, "https://acme.social/@woody")
    |> assign_link_form(%{})
  end

  defp assign_link_form(socket, params, action \\ nil) do
    changeset = Sites.change_social_media_link(%SocialMediaLink{}, params)

    socket
    |> assign(:link_params, params)
    |> assign(:link_form, to_form(changeset, action: action))
  end

  # The icon is a hidden field, so `<.input>` shows no errors for it. The
  # form only carries errors once it has an action (validate or submit).
  defp link_icon_errors(form), do: Enum.map(form[:icon].errors, &translate_error/1)
end
