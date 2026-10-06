defmodule FeatherWeb.SiteComponents do
  @moduledoc """
  Components of the site admin: the site shell (site title, preview
  button, site navigation, notices) that wraps every page under
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

  import FeatherWeb.CoreComponents

  alias FeatherWeb.Layouts
  alias Phoenix.LiveView.JS

  @doc """
  Renders the app layout with the site header and navigation.

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
      <div class="site-navigation card mb-4" id="site-navigation">
        <div class="card-body">
          <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-3">
            <div class="h4 m-0 d-flex align-items-center gap-2" id="site-title">
              <span>{@site.emoji}</span>
              <span>{@site.title}</span>
            </div>
            <a
              :if={@preview_path}
              href={@preview_path}
              target="_blank"
              id="site-preview-link"
              class="btn btn-outline-primary btn-sm"
            >
              <.icon name="eye" size={16} /> Preview
            </a>
          </div>
          <nav class="site-nav d-flex flex-wrap justify-content-between gap-2">
            <ul class="nav nav-pills">
              <.nav_item active={@active == :posts} navigate={"/sites/#{@site.public_id}/posts"}>
                <.icon name="pencil" size={16} /> Posts
              </.nav_item>
              <.nav_item active={@active == :pages} navigate={"/sites/#{@site.public_id}/pages"}>
                <.icon name="file-text" size={16} /> Pages
              </.nav_item>
              <.nav_item active={@active == :books} navigate={"/sites/#{@site.public_id}/books"}>
                <.icon name="book-open" size={16} /> Books
              </.nav_item>
              <.nav_item
                active={@active == :projects}
                navigate={"/sites/#{@site.public_id}/projects"}
              >
                <.icon name="rocket" size={16} /> Projects
              </.nav_item>
            </ul>
            <ul class="nav nav-pills">
              <.nav_item
                active={@active == :settings}
                navigate={"/sites/#{@site.public_id}/settings"}
              >
                <.icon name="settings" size={16} /> Settings
              </.nav_item>
              <.nav_item active={@active == :users} navigate={"/sites/#{@site.public_id}/users"}>
                <.icon name="users" size={16} /> Users
              </.nav_item>
              <.nav_item
                active={@active == :deployments}
                navigate={"/sites/#{@site.public_id}/deployments"}
              >
                <.icon name="package" size={16} /> Deployments
              </.nav_item>
            </ul>
          </nav>
        </div>
      </div>

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
  slot :inner_block, required: true

  defp nav_item(assigns) do
    ~H"""
    <li class="nav-item">
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
