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
      deploy={@site_deploy}
      preview_path={@site_preview_path}
      active={:settings}
    >
      <.header>
        Site settings
        <:subtitle>{@current_scope.site.title}</:subtitle>
      </.header>

      <div class="max-w-3xl">
        <.section_heading id="general-heading">General</.section_heading>
        <.form for={@form} id="site-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:title]} type="text" label="Title" placeholder="Timon's Blog" />
          <div class="grid gap-x-4 sm:grid-cols-[6rem_minmax(0,1fr)_12rem]">
            <.input field={@form[:emoji]} type="text" label="Emoji" class="text-center text-xl" />
            <.input field={@form[:domain]} type="text" label="Domain" placeholder="timon.blog" />
            <.input
              field={@form[:language_code]}
              type="select"
              label="Language"
              options={Languages.options()}
            />
          </div>
          <.input
            field={@form[:copyright]}
            type="text"
            label="Copyright notice"
            help="The copyright notice in the footer of your site. {{CurrentYear}} is replaced with the current year."
          />
          <.action_bar class="mt-6">
            <.button type="submit" variant={:primary} phx-disable-with="Saving…">Save</.button>
          </.action_bar>
        </.form>

        <section id="social-media" aria-labelledby="social-media-heading" class="mt-10">
          <.section_heading id="social-media-heading">Social media links</.section_heading>
          <.empty_state :if={@links_empty?} id="no-social-media-links" icon="globe">
            Add links to your social profiles. They are shown in the footer of your site.
          </.empty_state>

          <.list
            id="social-media-links"
            phx-update="stream"
            class={["mb-4", @links_empty? && "hidden"]}
          >
            <.list_row
              :for={{id, link} <- @streams.social_media_links}
              id={id}
              title={link.name}
              actions_label="Actions"
              menu={:always}
            >
              <:leading>
                <.tile><.brand_icon name={link.icon} class="size-5" /></.tile>
              </:leading>
              <:meta>
                <a href={link.url} target="_blank" rel="noopener" class="link link-hover">
                  {link.url}
                </a>
              </:meta>
              <:action
                id={"delete-#{id}"}
                icon="trash-2"
                label="Delete"
                on_click={JS.push("delete_link", value: %{id: link.id})}
                confirm={"Delete the link to #{link.name}?"}
                danger
              />
            </.list_row>
          </.list>

          <.button
            :if={!@adding_link?}
            id="add-link"
            variant={:ghost}
            size={:sm}
            icon="plus"
            phx-click="add_link"
          >
            Add link
          </.button>

          <.form
            :if={@adding_link?}
            for={@link_form}
            id="social-media-link-form"
            class="mt-6"
            phx-change="validate_link"
            phx-submit="save_link"
            aria-labelledby="new-link-heading"
          >
            <.section_heading id="new-link-heading" level={3}>New link</.section_heading>
            <fieldset class="fieldset">
              <legend class="fieldset-legend">Service</legend>
              <div id="social-media-services" class="flex flex-wrap gap-2">
                <button
                  :for={service <- @services}
                  type="button"
                  id={"service-#{service.icon}"}
                  class={[
                    "btn btn-square",
                    @link_form[:icon].value == service.icon &&
                      "btn-primary btn-soft ring-2 ring-primary"
                  ]}
                  title={service.name}
                  aria-label={service.name}
                  aria-pressed={to_string(@link_form[:icon].value == service.icon)}
                  phx-click={JS.push("pick_service", value: %{icon: service.icon})}
                >
                  <.brand_icon name={service.icon} class="size-5" />
                </button>
              </div>
              <p id="selected-service" class="text-sm" aria-live="polite">
                <%= if service = selected_service(@services, @link_form) do %>
                  {service.name}
                <% else %>
                  <span class="text-base-content/70">Pick a service</span>
                <% end %>
              </p>
              <.input field={@link_form[:icon]} type="hidden" />
              <p
                :for={msg <- link_icon_errors(@link_form)}
                class="flex items-center gap-1.5 text-sm text-error-ink"
                id="social-media-link-icon-error"
              >
                <.icon name="circle-alert" class="size-4 shrink-0" />{msg}
              </p>
            </fieldset>
            <div class="grid gap-x-4 sm:grid-cols-[12rem_minmax(0,1fr)]">
              <.input field={@link_form[:name]} type="text" label="Name" placeholder="Link name" />
              <.input
                field={@link_form[:url]}
                type="url"
                label="URL"
                placeholder={@url_placeholder}
              />
            </div>
            <.action_bar class="mt-4">
              <.button id="cancel-link" phx-click="cancel_link">Cancel</.button>
              <.button type="submit" variant={:primary} phx-disable-with="Saving…">
                Add link
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

    socket =
      with %SocialMediaLink{} = link <- Sites.get_social_media_link(scope, id),
           {:ok, _} <- Sites.delete_social_media_link(scope, link) do
        Publishing.publish_site(scope)
        put_flash(socket, :info, "Social media link was successfully deleted.")
      else
        nil -> put_flash(socket, :error, "This link no longer exists.")
        {:error, _reason} -> put_flash(socket, :error, "The link could not be deleted.")
      end

    links = Sites.list_social_media_links(scope)

    {:noreply,
     socket
     |> stream(:social_media_links, links, reset: true)
     |> assign(:links_empty?, links == [])}
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

  defp selected_service(services, form),
    do: Enum.find(services, &(&1.icon == form[:icon].value))

  # The icon is a hidden field, so `<.input>` shows no errors for it. The
  # form only carries errors once it has an action (validate or submit).
  defp link_icon_errors(form), do: Enum.map(form[:icon].errors, &translate_error/1)
end
