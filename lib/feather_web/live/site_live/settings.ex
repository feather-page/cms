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
  alias FeatherWeb.SiteAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Site settings
        <:subtitle>{@current_scope.site.title}</:subtitle>
      </.header>

      <.form for={@form} id="site-form" phx-change="validate" phx-submit="save" class="mb-5">
        <.input field={@form[:title]} type="text" label="Title" placeholder="Timon's Blog" />
        <div class="row">
          <div class="col-md-2">
            <.input field={@form[:emoji]} type="text" label="Emoji" />
          </div>
          <div class="col-md">
            <.input field={@form[:domain]} type="text" label="Domain" placeholder="timon.blog" />
          </div>
          <div class="col-md">
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
          <.button variant="primary" phx-disable-with="Saving...">Update site</.button>
          <.button href={SiteAuth.site_home_path(@current_scope.site)}>Cancel</.button>
        </div>
      </.form>

      <h2 class="h5 mb-3">Social media links</h2>

      <div :if={@links_empty?} id="no-social-media-links" class="alert alert-secondary">
        You can add links to your social profiles here. They will be displayed in the footer of your site.
      </div>

      <div :if={!@links_empty?} class="table-responsive mb-4">
        <table class="table align-middle">
          <thead>
            <tr>
              <th>Icon</th>
              <th>Name</th>
              <th>URL</th>
              <th><span class="visually-hidden">Actions</span></th>
            </tr>
          </thead>
          <tbody id="social-media-links" phx-update="stream">
            <tr :for={{id, link} <- @streams.social_media_links} id={id}>
              <td><.icon name={link.icon} /></td>
              <td>{link.name}</td>
              <td>
                <a href={link.url} target="_blank" rel="noopener">{link.url}</a>
              </td>
              <td class="text-end">
                <.button
                  id={"delete-#{id}"}
                  size="sm"
                  variant="danger"
                  phx-click={JS.push("delete_link", value: %{id: link.id})}
                  data-confirm="Are you sure?"
                  title="Delete"
                  aria-label="Delete"
                >
                  <.icon name="trash" size={16} />
                </.button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="card">
        <div class="card-header fw-semibold">Add link</div>
        <div class="card-body">
          <.form
            for={@link_form}
            id="social-media-link-form"
            phx-change="validate_link"
            phx-submit="save_link"
          >
            <div class="mb-3">
              <span class="form-label d-block">Service</span>
              <div id="social-media-services" class="d-flex flex-wrap gap-2">
                <button
                  :for={service <- @services}
                  type="button"
                  id={"service-#{service.icon}"}
                  class={[
                    "btn",
                    if(@link_form[:icon].value == service.icon,
                      do: "btn-primary active",
                      else: "btn-outline-secondary"
                    )
                  ]}
                  title={service.name}
                  aria-label={service.name}
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
            </div>
            <.input field={@link_form[:name]} type="text" label="Name" placeholder="Mastodon" />
            <.input
              field={@link_form[:url]}
              type="url"
              label="URL"
              placeholder={@url_placeholder}
            />
            <.button variant="primary" phx-disable-with="Saving...">Create link</.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
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
