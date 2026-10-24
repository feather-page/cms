defmodule FeatherWeb.SiteLive.Settings do
  @moduledoc """
  The settings of a site: emoji, title, domain, language, theme and
  copyright notice, the site's social media links, its mascots, its
  portrait, its bio, its fediverse name (ADR 0033) with the number of
  followers, its signing key, which members rotate, and the blocked
  accounts and servers, and the archive.org keys deploys use (ADR 0027).
  A new domain typed in for a site with a fediverse name brings a
  warning: saving it starts the account over.

  Each change counts as not deployed yet in the site shell's deploy
  control (`FeatherWeb.SiteAuth.refresh_deploy_status/1`).
  """
  use FeatherWeb, :live_view

  alias Feather.Accounts.Scope
  alias Feather.{Fediverse, Sites}
  alias Feather.Fediverse.Block
  alias Feather.Sites.{Languages, Site, SocialMediaLink, SocialMediaService}
  alias Feather.StaticSite.Themes
  alias FeatherWeb.SiteAuth

  @mascot_accept ~w(.png .webp)
  @mascot_fallback "The image is deleted. The feather.page theme shows your site's emoji instead."

  @image_slots [
    footer: %{
      label: "Footer mascot",
      hint: "Peeks over the top edge of the footer on every page. Wide, about 3:1.",
      accept: @mascot_accept,
      removed: @mascot_fallback
    },
    post_end: %{
      label: "Post end mascot",
      hint:
        "Stands next to the links to the newer and older post at the end of every post. About 4:5.",
      accept: @mascot_accept,
      removed: @mascot_fallback
    },
    projects: %{
      label: "Projects mascot",
      hint: "Stands next to the title of the projects page. About 4:5.",
      accept: @mascot_accept,
      removed: @mascot_fallback
    },
    portrait: %{
      label: "Portrait",
      hint: "A JPEG, PNG or WebP photo.",
      accept: ~w(.jpg .jpeg .png .webp),
      removed: "The image is deleted."
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
      unread_mentions={@site_unread_mentions}
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
          <.alert
            :if={@new_domain}
            id="domain-change-warning"
            tone={:warning}
            title="Your fediverse account starts over"
            class="mb-4"
          >
            With the new domain your site is a new account,
            @{@current_scope.site.fediverse_name}@{@new_domain}, which goes online with the next
            deploy. {Fediverse.handle(@current_scope.site)} loses its followers and the accounts it
            follows.
          </.alert>
          <.input
            field={@form[:theme]}
            type="select"
            label="Theme"
            options={Themes.options()}
            help="How your site looks."
          />
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
          <p id="mascots-hint" class="mb-4 text-sm text-base-content/70">
            Small illustrations of your site's characters, shown by the feather.page theme. Use a
            PNG or WebP with a transparent background. Where a mascot is missing, the theme shows
            your site's emoji.
          </p>
          <.list id="mascot-slots">
            <.image_slot
              :for={slot <- Sites.mascot_slots()}
              id={"mascot-#{slot}"}
              remove_id={"remove-mascot-#{slot}"}
              slot={slot}
              info={@image_slots[slot]}
              image={Map.fetch!(@current_scope.site, slot_assoc(slot))}
              site={@current_scope.site}
              upload={@uploads[slot_assoc(slot)]}
              error={@image_errors[slot]}
            />
          </.list>
        </section>

        <section id="portrait-section" aria-labelledby="portrait-heading" class="mt-10">
          <.section_heading id="portrait-heading">Portrait</.section_heading>
          <p id="portrait-hint" class="mb-4 text-sm text-base-content/70">
            A photo of you. The Simple sidebar theme shows it in its panel on wide screens; on phones
            in the home header and beside the bio in the footer. The others leave it out.
          </p>
          <.list id="portrait-slots">
            <.image_slot
              id="portrait"
              remove_id="remove-portrait"
              slot={:portrait}
              info={@image_slots[:portrait]}
              image={@current_scope.site.portrait_image}
              site={@current_scope.site}
              upload={@uploads.portrait_image}
              error={@image_errors[:portrait]}
            />
          </.list>
        </section>

        <section id="bio-section" aria-labelledby="bio-heading" class="mt-10">
          <.section_heading id="bio-heading">Bio</.section_heading>
          <p id="bio-hint" class="mb-4 text-sm text-base-content/70">
            A few sentences about you, as plain text. The Simple sidebar theme shows it on every
            page; the others leave it out.
          </p>
          <.form for={@bio_form} id="bio-form" phx-change="validate_bio" phx-submit="save_bio">
            <.input field={@bio_form[:bio]} type="textarea" label="Bio" hide_label rows="4" />
            <.action_bar class="mt-4">
              <.button type="submit" variant={:primary} phx-disable-with="Saving…">Save</.button>
            </.action_bar>
          </.form>
        </section>

        <section id="fediverse" aria-labelledby="fediverse-heading" class="mt-10">
          <.section_heading id="fediverse-heading">Fediverse</.section_heading>
          <p id="fediverse-hint" class="mb-4 text-sm text-base-content/70">
            With a fediverse name, your site becomes an account that people on Mastodon,
            micro.blog and other servers find by its handle. Its profile shows your site's title,
            bio and portrait. The name is fixed after the first deploy with it. A new domain
            starts the account over, without its followers.
          </p>

          <.list :if={@current_scope.site.fediverse_name} id="fediverse-account" class="mb-4">
            <.list_row id="fediverse-handle" title={Fediverse.handle(@current_scope.site)}>
              <:leading>
                <.tile><.icon name="globe" class="size-5" /></.tile>
              </:leading>
              <:meta>{Fediverse.account_url(@current_scope.site)}</:meta>
              <:trailing>
                <.badge
                  :if={Fediverse.online?(@current_scope.site)}
                  id="fediverse-status"
                  tone={:success}
                >
                  Online
                </.badge>
                <.badge :if={!Fediverse.online?(@current_scope.site)} id="fediverse-status">
                  Online with the next deploy
                </.badge>
              </:trailing>
            </.list_row>
            <.list_row id="fediverse-followers" title={followers_text(@fediverse_followers)}>
              <:leading>
                <.tile><.icon name="users" class="size-5" /></.tile>
              </:leading>
            </.list_row>
            <.list_row
              id="fediverse-key"
              title="Signing key"
              actions_label="Actions"
              menu={:always}
            >
              <:leading>
                <.tile><.icon name="key-round" class="size-5" /></.tile>
              </:leading>
              <:meta :if={Fediverse.key_pending?(@current_scope.site)}>
                A new key goes online with the next deploy. Until then the account signs with the
                current one.
              </:meta>
              <:meta :if={!Fediverse.key_pending?(@current_scope.site)}>
                Signs what the account sends to other servers.
              </:meta>
              <:trailing :if={Fediverse.key_pending?(@current_scope.site)}>
                <.badge id="fediverse-key-status">New key with the next deploy</.badge>
              </:trailing>
              <:action
                :if={!Fediverse.key_pending?(@current_scope.site)}
                id="rotate-key"
                icon="key-round"
                label="Rotate key"
                on_click="rotate_key"
                confirm="Rotate the account's key?"
                confirm_text="The new key goes online with the next deploy. From then on the account signs with it, and the current key is discarded."
                confirm_label="Rotate"
              />
            </.list_row>
          </.list>

          <.form
            :if={!Fediverse.online?(@current_scope.site)}
            for={@fediverse_form}
            id="fediverse-form"
            phx-change="validate_fediverse"
            phx-submit="save_fediverse"
          >
            <.input
              field={@fediverse_form[:fediverse_name]}
              type="text"
              label="Fediverse name"
              prefix="@"
              suffix={"@" <> @current_scope.site.domain}
              placeholder="timon"
              autocomplete="off"
              help="Leave it empty to keep your site out of the fediverse."
            />
            <.action_bar class="mt-4">
              <.button type="submit" variant={:primary} phx-disable-with="Saving…">Save</.button>
            </.action_bar>
          </.form>

          <div :if={@current_scope.site.fediverse_name} id="fediverse-blocks" class="mt-6">
            <.section_heading id="blocks-heading" level={3}>Blocked</.section_heading>
            <p id="blocks-hint" class="mb-4 text-sm text-base-content/70">
              Accounts and servers blocked from the menu of a mention or a Timeline post can
              neither follow your site nor reach its Mentions.
            </p>
            <.empty_state :if={@blocks_empty?} id="no-blocks" icon="ban">
              Nothing blocked.
            </.empty_state>
            <.list id="blocks" phx-update="stream" class={@blocks_empty? && "hidden"}>
              <.list_row
                :for={{id, block} <- @streams.blocks}
                id={id}
                title={Block.name(block)}
                actions_label="Actions"
                menu={:always}
              >
                <:leading>
                  <.tile>
                    <.icon
                      name={if Block.server?(block), do: "globe", else: "circle-user"}
                      class="size-5"
                    />
                  </.tile>
                </:leading>
                <:meta>{block_meta(block)}</:meta>
                <:action
                  id={"unblock-#{id}"}
                  icon="rotate-ccw"
                  label="Unblock"
                  on_click={JS.push("unblock", value: %{id: block.id})}
                />
              </.list_row>
            </.list>
          </div>
        </section>

        <section id="notifications" aria-labelledby="notifications-heading" class="mt-10">
          <.section_heading id="notifications-heading">
            Search engines and archive.org
          </.section_heading>
          <p id="notifications-hint" class="mb-4 text-sm text-base-content/70">
            After each deploy, the search engines that take IndexNow, such as Bing, are told which
            pages changed. With your archive.org keys, the Wayback Machine also saves them. You find
            the keys at <a
              href="https://archive.org/account/s3.php"
              target="_blank"
              rel="noopener"
              class="link"
            >archive.org/account/s3.php</a>.
          </p>

          <.list :if={@archive_org_keys?} id="archive-org-keys">
            <.list_row
              id="archive-org-keys-saved"
              title="archive.org keys saved"
              actions_label="Actions"
              menu={:always}
            >
              <:leading>
                <.tile><.icon name="search" class="size-5" /></.tile>
              </:leading>
              <:meta>Deploys ask archive.org to save the changed pages.</:meta>
              <:action
                id="remove-archive-org-keys"
                icon="trash-2"
                label="Remove"
                on_click="remove_archive_org_keys"
                confirm="Remove the archive.org keys?"
                confirm_text="Deploys no longer ask archive.org to save changed pages."
                confirm_label="Remove"
                danger
              />
            </.list_row>
          </.list>

          <.form
            :if={!@archive_org_keys?}
            for={@archive_org_form}
            id="archive-org-form"
            phx-submit="save_archive_org_keys"
          >
            <div class="grid gap-x-4 sm:grid-cols-2">
              <.input
                field={@archive_org_form[:access_key]}
                type="text"
                label="Access key"
                autocomplete="off"
              />
              <.input
                field={@archive_org_form[:secret_key]}
                type="password"
                label="Secret key"
                autocomplete="off"
              />
            </div>
            <.action_bar class="mt-4">
              <.button type="submit" variant={:primary} phx-disable-with="Saving…">Save</.button>
            </.action_bar>
          </.form>
        </section>
      </div>
    </.site_shell>
    """
  end

  attr :id, :string, required: true
  attr :remove_id, :string, required: true
  attr :slot, :atom, required: true
  attr :info, :map, required: true
  attr :image, :any, required: true
  attr :site, :any, required: true
  attr :upload, :any, required: true
  attr :error, :string, default: nil

  defp image_slot(assigns) do
    ~H"""
    <li id={@id} class="list-row items-center">
      <div
        id={"#{@id}-preview"}
        class="checkerboard flex h-20 w-28 items-center justify-center overflow-hidden rounded-box border border-base-content/10"
      >
        <img
          :if={@image}
          src={image_path(@site, @image, :preview)}
          alt=""
          class="max-h-full max-w-full object-contain"
        />
        <.icon :if={!@image && @slot == :portrait} name="circle-user" class="size-8 opacity-60" />
        <span :if={!@image && @slot != :portrait} class="text-3xl opacity-60" aria-hidden="true">
          {@site.emoji}
        </span>
      </div>
      <div class="list-col-grow min-w-0">
        <p class="font-medium">{@info.label}</p>
        <p class="text-sm text-base-content/70">{@info.hint}</p>
        <p
          :for={entry <- @upload.entries}
          :if={!entry.done?}
          class="mt-1 text-sm text-base-content/70"
        >
          Uploading {entry.client_name} – {entry.progress}%
        </p>
        <p
          :if={@error}
          id={"#{@id}-error"}
          class="mt-1 flex items-center gap-1.5 text-sm text-error-ink"
        >
          <.icon name="circle-alert" class="size-4 shrink-0" />{@error}
        </p>
        <div class="mt-2 flex flex-wrap items-center gap-2">
          <form id={"#{@id}-form"} phx-change="validate_upload" phx-submit="validate_upload">
            <label class="btn btn-sm focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-primary">
              <.icon name="upload" />{if @image, do: "Replace", else: "Upload"}
              <.live_file_input upload={@upload} class="sr-only" />
            </label>
          </form>
          <.button
            :if={@image}
            id={@remove_id}
            variant={:ghost}
            size={:sm}
            icon="trash-2"
            phx-click="remove_image"
            phx-value-slot={@slot}
            confirm={"Remove the #{String.downcase(@info.label)}?"}
            confirm_text={@info.removed}
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
    scope = Scope.put_site(scope, Sites.preload_images(scope.site))
    links = Sites.list_social_media_links(scope)

    {:ok,
     socket
     |> allow_image_uploads()
     |> assign(:current_scope, scope)
     |> assign(:image_slots, @image_slots)
     |> assign(:image_errors, %{})
     |> assign(:page_title, "Site settings")
     |> assign(:services, SocialMediaService.all())
     |> assign_form(:form, Sites.change_site(scope.site))
     |> assign(:bio_form, to_form(Sites.change_site(scope.site)))
     |> assign(:fediverse_form, to_form(Fediverse.change_name(scope.site)))
     |> assign(:fediverse_followers, Fediverse.count_followers(scope))
     |> assign_blocks(Fediverse.list_blocks(scope))
     |> assign_archive_org_keys()
     |> assign(:links_empty?, links == [])
     |> stream(:social_media_links, links)
     |> reset_link_form()}
  end

  @impl true
  def handle_event("validate", %{"site" => params}, socket) do
    changeset = Sites.change_site(socket.assigns.current_scope.site, params)
    {:noreply, assign_form(socket, :form, changeset, action: :validate)}
  end

  def handle_event("save", %{"site" => params}, socket), do: save_site(socket, :form, params)

  def handle_event("validate_bio", %{"site" => params}, socket) do
    changeset = Sites.change_site(socket.assigns.current_scope.site, params)
    {:noreply, assign(socket, :bio_form, to_form(changeset, action: :validate))}
  end

  def handle_event("save_bio", %{"site" => params}, socket),
    do: save_site(socket, :bio_form, params)

  def handle_event("validate_fediverse", %{"site" => params}, socket) do
    changeset = Fediverse.change_name(socket.assigns.current_scope.site, params)
    {:noreply, assign(socket, :fediverse_form, to_form(changeset, action: :validate))}
  end

  def handle_event("save_fediverse", %{"site" => params}, socket) do
    scope = socket.assigns.current_scope

    case Fediverse.update_name(scope, params) do
      {:ok, site} ->
        site = Sites.preload_images(site)

        {:noreply,
         socket
         |> assign(:current_scope, Scope.put_site(scope, site))
         |> SiteAuth.refresh_deploy_status()
         |> assign(:fediverse_form, to_form(Fediverse.change_name(site)))
         |> put_flash(:info, "The fediverse name was saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :fediverse_form, to_form(changeset, action: :update))}
    end
  end

  def handle_event("rotate_key", _params, socket) do
    scope = socket.assigns.current_scope

    case Fediverse.rotate_key(scope) do
      {:ok, site} ->
        {:noreply,
         socket
         |> assign(:current_scope, Scope.put_site(scope, Sites.preload_images(site)))
         |> SiteAuth.refresh_deploy_status()
         |> put_flash(:info, "The new key goes online with the next deploy.")}

      {:error, :not_an_account} ->
        {:noreply, put_flash(socket, :error, "The site has no fediverse name.")}
    end
  end

  def handle_event("unblock", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    block = Fediverse.get_block!(scope, id)
    :ok = Fediverse.unblock(scope, block)

    {:noreply,
     socket
     |> assign_blocks(Fediverse.list_blocks(scope))
     |> put_flash(:info, "Unblocked #{Block.name(block)}.")}
  end

  def handle_event("save_archive_org_keys", %{"archive_org_keys" => params}, socket) do
    case Sites.put_archive_org_keys(socket.assigns.current_scope, params) do
      :ok ->
        {:noreply,
         socket
         |> assign_archive_org_keys()
         |> put_flash(:info, "The archive.org keys were saved.")}

      {:error, changeset} ->
        changeset = without_secret_key(changeset)

        {:noreply,
         assign(socket, :archive_org_form, archive_org_form(changeset, action: :insert))}
    end
  end

  def handle_event("remove_archive_org_keys", _params, socket) do
    :ok = Sites.delete_archive_org_keys(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign_archive_org_keys()
     |> put_flash(:info, "The archive.org keys were removed.")}
  end

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
        {:noreply,
         socket
         |> SiteAuth.refresh_deploy_status()
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
        socket
        |> SiteAuth.refresh_deploy_status()
        |> put_flash(:info, "Social media link was successfully deleted.")
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

  def handle_event("validate_upload", _params, socket) do
    socket =
      Enum.reduce(Keyword.keys(@image_slots), socket, fn slot, socket ->
        upload = socket.assigns.uploads[slot_assoc(slot)]
        invalid = Enum.reject(upload.entries, & &1.valid?)

        case upload_errors(upload) ++ Enum.flat_map(invalid, &upload_errors(upload, &1)) do
          [] ->
            socket

          [error | _] ->
            invalid
            |> Enum.reduce(socket, &cancel_upload(&2, upload.name, &1.ref))
            |> put_image_error(slot, upload_error_message(error, slot))
        end
      end)

    {:noreply, socket}
  end

  def handle_event("remove_image", %{"slot" => slot}, socket) do
    case Enum.find(Keyword.keys(@image_slots), &(to_string(&1) == slot)) do
      nil ->
        {:noreply, socket}

      slot ->
        case remove_slot_image(socket.assigns.current_scope, slot) do
          {:ok, site} ->
            {:noreply,
             socket
             |> image_changed(site)
             |> put_flash(:info, "#{slot_label(slot)} was successfully removed.")}

          {:error, _changeset} ->
            {:noreply, put_image_error(socket, slot, "The image could not be removed.")}
        end
    end
  end

  defp allow_image_uploads(socket) do
    Enum.reduce(@image_slots, socket, fn {slot, info}, socket ->
      allow_upload(socket, slot_assoc(slot),
        accept: info.accept,
        max_entries: 1,
        max_file_size: Feather.Media.max_byte_size(),
        auto_upload: true,
        progress: &handle_image_progress/3
      )
    end)
  end

  defp handle_image_progress(name, entry, socket) do
    slot = Enum.find(Keyword.keys(@image_slots), &(slot_assoc(&1) == name))

    with true <- entry.done?,
         {:cont, socket} <- FeatherWeb.SiteAuth.check_access(socket) do
      scope = socket.assigns.current_scope

      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          {:ok, put_slot_image(scope, slot, path, entry.client_name)}
        end)

      case result do
        {:ok, site} ->
          {:noreply,
           socket
           |> image_changed(site)
           |> put_flash(:info, "#{slot_label(slot)} was successfully updated.")}

        {:error, %Ecto.Changeset{errors: errors}} ->
          message = image_error_message(Keyword.get(errors, :file))
          {:noreply, put_image_error(socket, slot, message)}
      end
    else
      {:halt, socket} -> {:noreply, socket}
      false -> {:noreply, socket}
    end
  end

  defp save_site(socket, form, params) do
    scope = socket.assigns.current_scope

    case Sites.update_site(scope, scope.site, params) do
      {:ok, site} ->
        scope = Scope.put_site(scope, site)

        {:noreply,
         socket
         |> assign(:current_scope, scope)
         |> SiteAuth.refresh_deploy_status()
         |> assign_form(form, Sites.change_site(site))
         |> assign(:fediverse_followers, Fediverse.count_followers(scope))
         |> put_flash(:info, "Site was successfully updated.")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, form, changeset, action: :update)}
    end
  end

  defp assign_form(socket, form, changeset, opts \\ [])

  defp assign_form(socket, :form, changeset, opts) do
    site = socket.assigns.current_scope.site
    new_domain = Fediverse.account?(site) && Ecto.Changeset.get_change(changeset, :domain)

    socket
    |> assign(:form, to_form(changeset, opts))
    |> assign(:new_domain, new_domain)
  end

  defp assign_form(socket, form, changeset, opts),
    do: assign(socket, form, to_form(changeset, opts))

  defp assign_blocks(socket, blocks) do
    socket
    |> assign(:blocks_empty?, blocks == [])
    |> stream(:blocks, blocks, reset: true)
  end

  defp assign_archive_org_keys(socket) do
    socket
    |> assign(:archive_org_keys?, Sites.archive_org_keys?(socket.assigns.current_scope))
    |> assign(:archive_org_form, archive_org_form(Sites.change_archive_org_keys()))
  end

  defp without_secret_key(changeset) do
    changeset
    |> Ecto.Changeset.delete_change(:secret_key)
    |> Map.update!(:params, &Map.put(&1, "secret_key", ""))
  end

  defp archive_org_form(changeset, opts \\ []),
    do: to_form(changeset, Keyword.put(opts, :as, :archive_org_keys))

  defp image_error_message({message, _opts}), do: "The file #{message}."
  defp image_error_message(nil), do: "The image could not be saved."

  defp slot_assoc(:portrait), do: :portrait_image
  defp slot_assoc(slot), do: Site.mascot_assoc(slot)

  defp put_slot_image(scope, :portrait, path, filename),
    do: Sites.put_portrait(scope, path, filename)

  defp put_slot_image(scope, slot, path, filename),
    do: Sites.put_mascot(scope, slot, path, filename)

  defp remove_slot_image(scope, :portrait), do: Sites.remove_portrait(scope)
  defp remove_slot_image(scope, slot), do: Sites.remove_mascot(scope, slot)

  defp image_changed(socket, site) do
    scope = Scope.put_site(socket.assigns.current_scope, site)

    socket
    |> assign(:current_scope, scope)
    |> assign(:image_errors, %{})
    |> SiteAuth.refresh_deploy_status()
  end

  defp put_image_error(socket, slot, message),
    do: assign(socket, :image_errors, Map.put(socket.assigns.image_errors, slot, message))

  defp slot_label(slot), do: @image_slots[slot].label

  defp upload_error_message(:too_large, _slot),
    do: "The file is too big (at most #{div(Feather.Media.max_byte_size(), 1024 * 1024)} MB)."

  defp upload_error_message(:not_accepted, :portrait),
    do: "Only JPEG, PNG and WebP files can be uploaded."

  defp upload_error_message(:not_accepted, _slot), do: "Only PNG and WebP files can be uploaded."
  defp upload_error_message(:too_many_files, _slot), do: "Please choose one file."
  defp upload_error_message(error, _slot), do: "Upload failed: #{inspect(error)}"

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

  defp block_meta(block) do
    kind = if Block.server?(block), do: "Server", else: "Account"
    "#{kind} · blocked #{time_ago(block.inserted_at)}"
  end

  defp followers_text(0), do: "No followers yet"
  defp followers_text(1), do: "1 follower"
  defp followers_text(count), do: "#{count} followers"
end
