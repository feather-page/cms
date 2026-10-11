defmodule FeatherWeb.Layouts do
  @moduledoc """
  The layouts of the admin.

  The root layout (`layouts/root.html.heex`) loads the app assets (Tailwind,
  daisyUI and the `setzkasten` theme, see `assets/css/app.css`); `app/1`
  renders the top bar, the page container, the flash toasts (setzkasten's
  `flash_group/1`, called only here) and the shared confirmation dialog, and
  is used explicitly by every LiveView:

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        ...
      </Layouts.app>
  """
  use FeatherWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout: the shell (brand, navigation, user menu), the
  main container, the flash toasts and the one confirmation dialog of the
  page (`#confirm-delete`, opened by every `confirm` of a button or list
  row action).

  Without `nav` it is a top bar (the site list, the account). With `nav`
  (maps of setzkasten's `:nav` entries) it is setzkasten's sidebar layout:
  `FeatherWeb.SiteComponents.site_shell/1` passes the site's sections, the
  site switcher as `leading` (below the brand), the deploy control as
  `nav_footer` and its compact form for narrower screens as `trailing`
  (before the user menu in the top bar). From `xl` the user menu sits at
  the foot of the sidebar and shows the email address.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :nav, :list, default: [], doc: "sidebar entries; none means a top bar"

  attr :bare, :boolean,
    default: false,
    doc: "only the page, without top bar (the login pages, which show the logo themselves)"

  attr :current, :atom, default: nil, doc: "the key of the current nav entry"

  slot :leading,
    doc:
      "after the brand (below it in the sidebar); gets where it renders, see setzkasten's app_shell"

  slot :trailing, doc: "before the user menu"
  slot :nav_footer, doc: "the bottom of the sidebar; gets where it renders"
  slot :bar, doc: "detail pages: breadcrumbs and status in place of the brand in the top bar"
  slot :bar_actions, doc: "detail pages: the page's own actions at the end of the bar"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main :if={@bare} id="main" class="px-4 py-10 sm:py-16">{render_slot(@inner_block)}</main>
    <.app_shell
      :if={!@bare}
      layout={if @nav == [], do: :topbar, else: :sidebar}
      dock={@nav != []}
      current={@current}
      skip_label="Skip to content"
      nav_label="Main"
      expand_label="Expand sidebar"
      more_label="More"
    >
      <:brand :let={place}>
        <div class={["flex min-w-0 flex-1 items-center gap-2", place != :bar && "flex-wrap"]}>
          <.link
            navigate={~p"/"}
            class="btn btn-ghost px-2 text-lg font-semibold"
            aria-label="Feather, all sites"
          >
            <.plush name="feather" size={:md} />
            <span class={@leading != [] && "max-sm:hidden"}>Feather</span>
          </.link>
          <div :if={@leading != []} class={["min-w-0", place != :bar && "basis-full"]}>
            {render_slot(@leading, place)}
          </div>
        </div>
      </:brand>
      <:nav
        :for={item <- @nav}
        key={item.key}
        label={item.label}
        navigate={item.navigate}
        icon={item.icon}
        section={item[:section]}
      />
      <:nav_footer :let={place} :if={@nav_footer != []}>
        {render_slot(@nav_footer, place)}
      </:nav_footer>
      <:bar :if={@bar != []}>{render_slot(@bar)}</:bar>
      <:bar_actions :if={@bar_actions != []}>{render_slot(@bar_actions)}</:bar_actions>
      <:account :let={place}>
        {if place == :bar, do: render_slot(@trailing)}
        <.dropdown
          :if={@current_scope && @current_scope.user}
          id={"user-menu-#{place}"}
          label="Account"
          align={if place == :bar, do: :end, else: :start}
          position={if place == :sidebar, do: :top, else: :bottom}
          variant={:ghost}
          chevron={false}
          class={place == :sidebar && "w-full"}
          trigger_class={if place == :sidebar, do: "w-full justify-start", else: "btn-square"}
        >
          <:trigger>
            <.icon name="circle-user" class="size-5 shrink-0" />
            <span :if={place == :sidebar} class="truncate font-normal">
              {@current_scope.user.email}
            </span>
          </:trigger>
          <:header :if={place == :bar}>
            <span id="current-user-email">{@current_scope.user.email}</span>
          </:header>
          <:item navigate={~p"/users/settings"} icon="settings">Account settings</:item>
          <:item href={~p"/users/log-out"} method="delete" icon="log-out">Log out</:item>
        </.dropdown>
        <.button
          :if={!(@current_scope && @current_scope.user)}
          navigate={~p"/users/log-in"}
          size={:sm}
        >
          Log in
        </.button>
      </:account>
      {render_slot(@inner_block)}
    </.app_shell>

    <.flash_group
      flash={@flash}
      close_label="Close"
      client_error={gettext("We can't find the internet")}
      server_error={gettext("Something went wrong!")}
      reconnecting={gettext("Attempting to reconnect")}
    />
    <.confirm_dialog
      title="Delete for good?"
      text="This cannot be undone."
      confirm_label="Delete"
      cancel_label="Cancel"
      close_label="Close"
    />
    """
  end
end
