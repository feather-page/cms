defmodule FeatherWeb.SiteComponents do
  @moduledoc """
  Components of the site admin: the site shell (site switcher, preview
  button, section navigation, notices) that wraps every page under
  `/sites/:site_id`, plus small building blocks shared by its pages (empty
  states, pagination, image URLs).

  Pages under `/sites/:site_id` live in the `:site` live_session, whose
  `FeatherWeb.SiteAuth` on_mount hook assigns `site_notices` and
  `site_preview_path`:

      <.site_shell
        flash={@flash}
        current_scope={@current_scope}
        notices={@site_notices}
        preview_path={@site_preview_path}
        active={:posts}
      >
        ...
      </.site_shell>
  """
  use Phoenix.Component
  use Gettext, backend: FeatherWeb.Gettext

  use FeatherWeb, :verified_routes

  import FeatherWeb.CoreComponents

  alias FeatherWeb.Layouts
  alias Phoenix.LiveView.JS

  @doc """
  Renders the app layout with the site switcher and the preview button
  in the top bar and the section navigation above the page.

  `active` marks the current navigation item: `:posts`, `:pages`,
  `:books`, `:projects`, `:settings`, `:users` or `:deployments`.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, required: true
  attr :active, :atom, default: nil
  attr :notices, :list, default: [], doc: "site notices, see FeatherWeb.SiteAuth"
  attr :preview_path, :string, default: nil, doc: "the preview of the site, if any"
  slot :inner_block, required: true

  def site_shell(assigns) do
    assigns = assign(assigns, :site, assigns.current_scope.site)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <:leading>
        <.live_component module={FeatherWeb.SiteSwitcher} id="site-switcher" scope={@current_scope} />
      </:leading>
      <:trailing>
        <a
          :if={@preview_path}
          href={@preview_path}
          target="_blank"
          id="site-preview-link"
          class="btn btn-light btn-sm app-topbar__preview"
          aria-label="Preview"
        >
          <.icon name="eye" size={16} /><span class="d-none d-sm-inline">Preview</span>
        </a>
      </:trailing>
      <:subnav>
        <nav class="site-nav mb-4" id="site-navigation" aria-label="Site" phx-hook="SiteNav">
          <ul class="nav nav-underline flex-nowrap overflow-x-auto">
            <.nav_item active={@active == :posts} navigate={~p"/sites/#{@site.public_id}/posts"}>
              Posts
            </.nav_item>
            <.nav_item active={@active == :pages} navigate={~p"/sites/#{@site.public_id}/pages"}>
              Pages
            </.nav_item>
            <.nav_item active={@active == :books} navigate={~p"/sites/#{@site.public_id}/books"}>
              Books
            </.nav_item>
            <.nav_item
              active={@active == :projects}
              navigate={~p"/sites/#{@site.public_id}/projects"}
            >
              Projects
            </.nav_item>
            <.nav_item
              class="ms-auto"
              active={@active == :settings}
              navigate={~p"/sites/#{@site.public_id}/settings"}
            >
              Settings
            </.nav_item>
            <.nav_item active={@active == :users} navigate={~p"/sites/#{@site.public_id}/users"}>
              Users
            </.nav_item>
            <.nav_item
              active={@active == :deployments}
              navigate={~p"/sites/#{@site.public_id}/deployments"}
            >
              Deployments
            </.nav_item>
          </ul>
        </nav>
      </:subnav>

      {render_slot(@inner_block)}

      <div id="site-notices" class="site-notices" aria-live="polite">
        <div
          :for={notice <- @notices}
          id={"site-notice-#{notice.id}"}
          class="alert alert-info d-flex align-items-start gap-2"
          role="status"
        >
          <.icon name="info" />
          <div class="flex-grow-1">
            <span>{notice.message}</span>
            <a :if={notice.url} href={notice.url} target="_blank" class="d-block">
              {notice.url}
            </a>
          </div>
          <button
            type="button"
            class="btn-close"
            aria-label={gettext("close")}
            phx-click={JS.push("dismiss_site_notice", value: %{id: notice.id})}
          ></button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :active, :boolean, default: false
  attr :navigate, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp nav_item(assigns) do
    ~H"""
    <li class={["nav-item", @class]}>
      <.link
        navigate={@navigate}
        class={["nav-link", @active && "active"]}
        aria-current={@active && "page"}
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end

  @doc """
  Renders an empty state with an emoji, a message and an optional action.
  """
  attr :id, :string, required: true
  attr :emoji, :string, required: true
  attr :message, :string, required: true
  attr :subtitle, :string, default: nil
  attr :action_label, :string, default: nil
  attr :action_navigate, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div id={@id} class="empty-state text-center p-5 mb-4">
      <div class="empty-state__emoji mb-2">{@emoji}</div>
      <p class="mb-1">{@message}</p>
      <p :if={@subtitle} class="text-body-secondary small">{@subtitle}</p>
      <.button :if={@action_label} navigate={@action_navigate} variant="primary" size="sm">
        {@action_label}
      </.button>
    </div>
    """
  end

  @doc """
  Renders pagination links when there is more than one page. `path` gets
  the page number and returns the URL to patch to.
  """
  attr :pagination, Feather.Pagination, required: true
  attr :path, :any, required: true, doc: "a function of the page number"
  attr :id, :string, default: "pagination"

  def pagination(assigns) do
    ~H"""
    <nav :if={@pagination.total_pages > 1} id={@id} aria-label="Pagination" class="mt-4">
      <ul class="pagination justify-content-center">
        <li class={["page-item", @pagination.page == 1 && "disabled"]}>
          <.link patch={@path.(max(@pagination.page - 1, 1))} class="page-link">
            Previous
          </.link>
        </li>
        <li
          :for={page <- 1..@pagination.total_pages}
          class={["page-item", page == @pagination.page && "active"]}
        >
          <.link
            patch={@path.(page)}
            class="page-link"
            aria-current={page == @pagination.page && "page"}
          >
            {page}
          </.link>
        </li>
        <li class={["page-item", @pagination.page == @pagination.total_pages && "disabled"]}>
          <.link
            patch={@path.(min(@pagination.page + 1, @pagination.total_pages))}
            class="page-link"
          >
            Next
          </.link>
        </li>
      </ul>
    </nav>
    """
  end

  @doc """
  The admin URL of an image of the site (served by
  `FeatherWeb.ImageController`), optionally of a variant such as
  `"mobile_x1.webp"`.
  """
  @spec image_path(Feather.Sites.Site.t(), Feather.Media.Image.t() | nil, String.t() | nil) ::
          String.t() | nil
  def image_path(site, image, variant \\ nil)
  def image_path(_site, nil, _variant), do: nil

  def image_path(site, image, nil),
    do: Feather.Content.Blocks.image_url(site, image.public_id)

  def image_path(site, image, variant),
    do: Feather.Content.Blocks.image_url(site, image.public_id) <> "?variant=#{variant}"

  @doc "Renders a rating as stars, e.g. ★★★★☆."
  @spec stars(integer() | nil) :: String.t()
  def stars(rating) when is_integer(rating) and rating > 0,
    do: String.duplicate("★", rating) <> String.duplicate("☆", 5 - rating)

  def stars(_rating), do: ""
end
