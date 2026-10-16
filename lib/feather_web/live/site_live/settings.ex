defmodule FeatherWeb.SiteLive.Settings do
  @moduledoc """
  The settings of a site: emoji, title, domain, language and copyright
  notice, the site's social media links and its mascots.

  Saving the site or changing its links or mascots publishes the staging
  targets (`Feather.Publishing.publish_site/1`), like Rails did.
  """
  use FeatherWeb, :live_view

  alias Feather.Accounts.Scope
  alias Feather.{Publishing, Sites}
  alias Feather.Sites.{Languages, Site, SocialMediaLink, SocialMediaService}

  @mascots [
    footer: %{
      label: "Footer mascot",
      hint: "Peeks over the top edge of the footer on every page. Wide, about 3:1."
    },
    post_end: %{
      label: "Post end mascot",
      hint:
        "Stands next to the links to the newer and older post at the end of every post. About 4:5."
    },
    projects: %{
      label: "Projects mascot",
      hint: "Stands next to the title of the projects page. About 4:5."
    }
  ]

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

        <section id="mascots" aria-labelledby="mascots-heading" class="mt-10">
          <.section_heading id="mascots-heading">Mascots</.section_heading>
          <p class="mb-4 text-sm text-base-content/70">
            Small illustrations of your site's characters. Use a PNG or WebP with a transparent
            background. Where a mascot is missing, your site shows its emoji.
          </p>
          <.list id="mascot-slots">
            <.mascot_slot
              :for={{slot, info} <- @mascots}
              slot={slot}
              label={info.label}
              hint={info.hint}
              image={Map.fetch!(@current_scope.site, Site.mascot_assoc(slot))}
              site={@current_scope.site}
              upload={@uploads[Site.mascot_assoc(slot)]}
              error={@mascot_errors[slot]}
            />
          </.list>
        </section>
      </div>
    </.site_shell>
    """
  end

  attr :slot, :atom, required: true
  attr :label, :string, required: true
  attr :hint, :string, required: true
  attr :image, :any, required: true
  attr :site, :any, required: true
  attr :upload, :any, required: true
  attr :error, :string, default: nil

  defp mascot_slot(assigns) do
    ~H"""
    <li id={"mascot-#{@slot}"} class="list-row items-center">
      <div
        id={"mascot-#{@slot}-preview"}
        class="checkerboard flex h-20 w-28 items-center justify-center overflow-hidden rounded-box border border-base-content/10"
      >
        <img
          :if={@image}
          src={image_path(@site, @image, "mobile_x1.webp")}
          alt=""
          class="max-h-full max-w-full object-contain"
        />
        <span :if={!@image} class="text-3xl opacity-60" aria-hidden="true">{@site.emoji}</span>
      </div>
      <div class="list-col-grow min-w-0">
        <p class="font-medium">{@label}</p>
        <p class="text-sm text-base-content/70">{@hint}</p>
        <p
          :for={entry <- @upload.entries}
          :if={!entry.done?}
          class="mt-1 text-sm text-base-content/70"
        >
          Uploading {entry.client_name} – {entry.progress}%
        </p>
        <p
          :if={@error}
          id={"mascot-#{@slot}-error"}
          class="mt-1 flex items-center gap-1.5 text-sm text-error-ink"
        >
          <.icon name="circle-alert" class="size-4 shrink-0" />{@error}
        </p>
        <div class="mt-2 flex flex-wrap items-center gap-2">
          <form
            id={"mascot-#{@slot}-form"}
            phx-change="validate_mascot"
            phx-submit="validate_mascot"
          >
            <label class="btn btn-sm focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-primary">
              <.icon name="upload" />{if @image, do: "Replace", else: "Upload"}
              <.live_file_input upload={@upload} class="sr-only" />
            </label>
          </form>
          <.button
            :if={@image}
            id={"remove-mascot-#{@slot}"}
            variant={:ghost}
            size={:sm}
            icon="trash-2"
            phx-click="remove_mascot"
            phx-value-slot={@slot}
            confirm={"Remove the #{String.downcase(@label)}?"}
            confirm_text="The image is deleted. Your site shows its emoji instead."
            confirm_label="Remove"
          >
            Remove
          </.button>
        </div>
      </div>
    </li>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    scope = Scope.put_site(scope, Sites.preload_mascots(scope.site))
    links = Sites.list_social_media_links(scope)

    socket =
      Enum.reduce(Sites.mascot_slots(), socket, fn slot, socket ->
        allow_upload(socket, Site.mascot_assoc(slot),
          accept: ~w(.png .webp),
          max_entries: 1,
          max_file_size: Feather.Media.max_byte_size(),
          auto_upload: true,
          progress: &handle_mascot_progress/3
        )
      end)

    {:ok,
     socket
     |> assign(:current_scope, scope)
     |> assign(:mascots, @mascots)
     |> assign(:mascot_errors, %{})
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

  ## Mascots

  def handle_event("validate_mascot", _params, socket) do
    socket =
      Enum.reduce(Sites.mascot_slots(), socket, fn slot, socket ->
        upload = socket.assigns.uploads[Site.mascot_assoc(slot)]
        invalid = Enum.reject(upload.entries, & &1.valid?)

        case upload_errors(upload) ++ Enum.flat_map(invalid, &upload_errors(upload, &1)) do
          [] ->
            socket

          [error | _] ->
            invalid
            |> Enum.reduce(socket, &cancel_upload(&2, upload.name, &1.ref))
            |> put_mascot_error(slot, upload_error_message(error))
        end
      end)

    {:noreply, socket}
  end

  def handle_event("remove_mascot", %{"slot" => slot}, socket) do
    case Enum.find(Sites.mascot_slots(), &(to_string(&1) == slot)) do
      nil ->
        {:noreply, socket}

      slot ->
        case Sites.remove_mascot(socket.assigns.current_scope, slot) do
          {:ok, site} ->
            {:noreply,
             socket
             |> mascot_changed(site)
             |> put_flash(:info, "#{mascot_label(slot)} was successfully removed.")}

          {:error, _changeset} ->
            {:noreply, put_mascot_error(socket, slot, "The mascot could not be removed.")}
        end
    end
  end

  defp handle_mascot_progress(name, entry, socket) do
    slot = Enum.find(Sites.mascot_slots(), &(Site.mascot_assoc(&1) == name))

    with true <- entry.done?,
         {:cont, socket} <- FeatherWeb.SiteAuth.check_access(socket) do
      scope = socket.assigns.current_scope

      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          {:ok, Sites.put_mascot(scope, slot, path, entry.client_name)}
        end)

      case result do
        {:ok, site} ->
          {:noreply,
           socket
           |> mascot_changed(site)
           |> put_flash(:info, "#{mascot_label(slot)} was successfully updated.")}

        {:error, %Ecto.Changeset{errors: errors}} ->
          message =
            case Keyword.get(errors, :file) do
              {message, _opts} -> "The file #{message}."
              nil -> "The image could not be saved."
            end

          {:noreply, put_mascot_error(socket, slot, message)}
      end
    else
      {:halt, socket} -> {:noreply, socket}
      false -> {:noreply, socket}
    end
  end

  defp mascot_changed(socket, site) do
    scope = Scope.put_site(socket.assigns.current_scope, site)
    Publishing.publish_site(scope)

    socket
    |> assign(:current_scope, scope)
    |> assign(:mascot_errors, %{})
  end

  defp put_mascot_error(socket, slot, message),
    do: assign(socket, :mascot_errors, Map.put(socket.assigns.mascot_errors, slot, message))

  defp mascot_label(slot), do: @mascots[slot].label

  defp upload_error_message(:too_large),
    do: "The file is too big (at most #{div(Feather.Media.max_byte_size(), 1024 * 1024)} MB)."

  defp upload_error_message(:not_accepted), do: "Only PNG and WebP files can be uploaded."
  defp upload_error_message(:too_many_files), do: "Please choose one file."
  defp upload_error_message(error), do: "Upload failed: #{inspect(error)}"

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
