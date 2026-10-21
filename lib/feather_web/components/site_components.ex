defmodule FeatherWeb.SiteComponents do
  @moduledoc """
  Components of the site admin: the site shell (site switcher, section
  navigation, deploy control and preview link, notices) that wraps every
  page under `/sites/:site_id`, plus small building blocks shared by its
  pages (pagination, image URLs, star ratings).

  Pages under `/sites/:site_id` live in the `:site` live_session, whose
  `FeatherWeb.SiteAuth` on_mount hook assigns `site_notices` and
  `site_deploy`:

      <.site_shell
        flash={@flash}
        current_scope={@current_scope}
        notices={@site_notices}
        deploy={@site_deploy}
        active={:posts}
      >
        ...
      </.site_shell>
  """
  use Phoenix.Component
  use Gettext, backend: FeatherWeb.Gettext

  use FeatherWeb, :verified_routes

  use Setzkasten

  alias Feather.Content.Blocks
  alias Feather.Media.Variants
  alias Feather.Publishing
  alias FeatherWeb.Layouts
  alias Phoenix.LiveView.JS

  @doc """
  Renders the app layout as a sidebar: the site switcher below the brand,
  the site's sections, and the deploy control at the bottom (on narrower
  screens in its compact form next to the user menu).

  `active` marks the current section: `:posts`, `:pages`, `:books`,
  `:projects`, `:settings`, `:redirects`, `:users` or `:deployments`.
  `deploy` is the `site_deploy` assign of `FeatherWeb.SiteAuth`. Detail
  pages pass `bar` (breadcrumbs and status), which takes the place of
  brand and site switcher in the top bar, and `bar_actions` (their own
  actions); there the deploy button shows as an icon with the count below
  `lg`, and on phones setzkasten leaves the global actions out of the bar.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, required: true
  attr :active, :atom, default: nil
  attr :notices, :list, default: [], doc: "site notices, see FeatherWeb.SiteAuth"
  attr :deploy, :map, default: nil, doc: "the deploy status, see FeatherWeb.SiteAuth"
  slot :bar, doc: "detail pages: breadcrumbs and status, see setzkasten's app_shell"
  slot :bar_actions, doc: "detail pages: the page's own actions, see setzkasten's app_shell"
  slot :inner_block, required: true

  def site_shell(assigns) do
    site = assigns.current_scope.site

    assigns =
      assign(assigns,
        site: site,
        nav: nav(site),
        preview_path: ~p"/preview/#{site.public_id}"
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav} current={@active}>
      <:bar :if={@bar != []}>{render_slot(@bar)}</:bar>
      <:bar_actions :if={@bar_actions != []}>{render_slot(@bar_actions)}</:bar_actions>
      <:leading :let={place}>
        <.live_component
          module={FeatherWeb.SiteSwitcher}
          id={"site-switcher-#{place}"}
          scope={@current_scope}
        />
      </:leading>
      <:nav_footer :let={place}>
        <.deploy_panel
          deploy={@deploy}
          domain={@site.domain}
          preview_path={@preview_path}
          place={place}
        />
      </:nav_footer>
      <:trailing>
        <div class="flex items-center gap-1 xl:hidden">
          <.button
            href={@preview_path}
            target="_blank"
            variant={:ghost}
            icon="eye"
            icon_only
            label="Preview"
          />
          <.deploy_button deploy={@deploy} />
        </div>
      </:trailing>

      <div id="site-notices" class={["grid gap-2", @notices != [] && "mb-6"]} aria-live="polite">
        <.alert
          :for={notice <- @notices}
          id={"site-notice-#{notice.id}"}
          tone={notice.kind}
          title={notice.title}
          on_close={JS.push("dismiss_site_notice", value: %{id: notice.id})}
          close_label={gettext("close")}
        >
          {notice.message}
          <.link
            :if={notice.link_label && !notice.external}
            navigate={notice.url}
            class="link block"
          >
            {notice.link_label}
          </.link>
          <a
            :if={notice.url && !notice.link_label}
            href={notice.url}
            target="_blank"
            class="link block break-all"
          >
            {notice.url}
          </a>
          <:actions :if={notice.external && notice.url}>
            <.button href={notice.url} target="_blank" rel="noopener" size={:sm} icon="external-link">
              {notice.link_label}
            </.button>
          </:actions>
          <:actions :if={notice.retry}>
            <.button
              id={"retry-deploy-#{notice.id}"}
              size={:sm}
              icon="rotate-ccw"
              phx-click={JS.push("retry_deploy", value: %{id: notice.id})}
            >
              Retry
            </.button>
          </:actions>
        </.alert>
      </div>

      {render_slot(@inner_block)}
    </Layouts.app>
    """
  end

  defp nav(site) do
    [
      %{
        key: :posts,
        label: "Posts",
        icon: "file-text",
        navigate: ~p"/sites/#{site.public_id}/posts"
      },
      %{key: :pages, label: "Pages", icon: "file", navigate: ~p"/sites/#{site.public_id}/pages"},
      %{
        key: :books,
        label: "Books",
        icon: "book-open",
        navigate: ~p"/sites/#{site.public_id}/books"
      },
      %{
        key: :projects,
        label: "Projects",
        icon: "folder-kanban",
        navigate: ~p"/sites/#{site.public_id}/projects"
      },
      %{
        key: :settings,
        label: "Settings",
        icon: "settings",
        section: "Site",
        navigate: ~p"/sites/#{site.public_id}/settings"
      },
      %{
        key: :redirects,
        label: "Redirects",
        icon: "signpost",
        section: "Site",
        navigate: ~p"/sites/#{site.public_id}/redirects"
      },
      %{
        key: :users,
        label: "Users",
        icon: "users",
        section: "Site",
        navigate: ~p"/sites/#{site.public_id}/users"
      },
      %{
        key: :deployments,
        label: "Deployments",
        icon: "globe",
        section: "Site",
        navigate: ~p"/sites/#{site.public_id}/deployments"
      }
    ]
  end

  @doc """
  The deploy control at the bottom of the sidebar: while the site
  deploys, the step; with changes its deployment target does not show
  yet, their number and a button that deploys the site (`"deploy_site"`,
  see `FeatherWeb.SiteAuth`); otherwise since when the site is live at its
  domain. Below it the link to the site's preview.
  """
  attr :deploy, :map, required: true
  attr :domain, :string, required: true
  attr :preview_path, :string, required: true
  attr :place, :atom, required: true, doc: "where the sidebar renders it, for unique ids"

  def deploy_panel(assigns) do
    assigns = assign(assigns, :state, deploy_state(assigns.deploy))

    ~H"""
    <div
      id={"deploy-panel-#{@place}"}
      class="grid gap-2 px-5 py-4 text-sm"
      aria-live="polite"
    >
      <%= case @state do %>
        <% {:running, step} -> %>
          <p class="flex items-center gap-2">
            <span class="loading loading-spinner loading-xs"></span>
            <span class="wrap-anywhere">Deploying to {@domain}</span>
          </p>
          <p class="text-sidebar-muted">{Publishing.deploy_step_label(step, :running)}</p>
        <% {:pending, count} -> %>
          <p class="flex items-center gap-2">
            <span class="status status-warning" aria-hidden="true"></span>
            {pending_text(count)}
          </p>
          <.button
            id={"deploy-site-#{@place}"}
            size={:sm}
            icon="rocket"
            phx-click="deploy_site"
          >
            Deploy
          </.button>
        <% {:live, deployed_at} -> %>
          <p class="flex items-center gap-2">
            <span class="status status-success" aria-hidden="true"></span>
            Live · {time_ago(deployed_at)}
          </p>
          <a
            href={"https://#{@domain}"}
            target="_blank"
            rel="noopener"
            class="link link-hover wrap-anywhere text-sidebar-muted"
          >
            {@domain}
          </a>
        <% :none -> %>
      <% end %>
      <a
        href={@preview_path}
        target="_blank"
        id={"site-preview-link-#{@place}"}
        class="flex items-center gap-1.5 text-sidebar-muted hover:text-sidebar-content"
      >
        <.icon name="eye" class="size-4" /> Preview
      </a>
    </div>
    """
  end

  @doc "The compact deploy control next to the user menu, below the full sidebar."
  attr :deploy, :map, required: true

  def deploy_button(assigns) do
    assigns = assign(assigns, :state, deploy_state(assigns.deploy))

    ~H"""
    <%= case @state do %>
      <% {:running, step} -> %>
        <span class="btn btn-sm btn-ghost pointer-events-none" role="status">
          <span class="loading loading-spinner loading-xs"></span>
          <span class="max-sm:sr-only">{Publishing.deploy_step_label(step, :running)}</span>
        </span>
      <% {:pending, count} -> %>
        <.button
          id="deploy-site-compact"
          variant={:ghost}
          size={:sm}
          icon="rocket"
          phx-click="deploy_site"
          aria-label={"Deploy, #{pending_text(count)}"}
        >
          <span class="max-lg:hidden">Deploy</span>
          <span class="flex items-center gap-1 tabular-nums">
            <span class="status status-warning" aria-hidden="true"></span>{count}
          </span>
        </.button>
      <% _ -> %>
    <% end %>
    """
  end

  @doc """
  The sentence of the delete confirmation of a post, page, project or
  review (`noun`, e.g. "post"): deleting does not touch the deployed
  site, so a published record stays live until the next deploy. Nil for
  a draft (the dialog's default sentence).
  """
  @spec delete_text(String.t(), map()) :: String.t() | nil
  def delete_text(noun, record) do
    if !Feather.Content.draft?(record),
      do: "Removes the #{noun} from Feather. It stays on the live site until the next deploy."
  end

  defp deploy_state(nil), do: :none
  defp deploy_state(%{target: nil}), do: :none

  defp deploy_state(%{target: target, pending: pending, progress: progress}) do
    cond do
      target.deploying or progress != nil -> {:running, (progress && progress.step) || :build}
      pending > 0 -> {:pending, pending}
      true -> {:live, target.last_deployed_at}
    end
  end

  defp pending_text(1), do: "1 change not live"
  defp pending_text(count), do: "#{count} changes not live"

  @doc """
  How long ago `at` was: "just now", "5 min ago", "3 h ago", "2 days ago",
  from a week on the date (`%d/%m/%Y`).
  """
  @spec time_ago(DateTime.t() | nil) :: String.t()
  def time_ago(nil), do: "not deployed yet"

  def time_ago(at) do
    case DateTime.diff(DateTime.utc_now(), at, :minute) do
      minutes when minutes < 1 -> "just now"
      minutes when minutes < 60 -> "#{minutes} min ago"
      minutes when minutes < 60 * 24 -> "#{div(minutes, 60)} h ago"
      minutes when minutes < 60 * 24 * 2 -> "1 day ago"
      minutes when minutes < 60 * 24 * 7 -> "#{div(minutes, 60 * 24)} days ago"
      _ -> Calendar.strftime(at, "%d/%m/%Y")
    end
  end

  @doc """
  Renders pagination links when there is more than one page. `path` gets
  the page number and returns the URL to patch to.

  Lists every page up to seven pages; beyond that the first, the last and
  the neighbours of the current page with gaps in between, so the bar
  keeps its width with hundreds of pages. Phones get Previous, the position
  ("Page 3 of 12") and Next.
  """
  attr :pagination, Feather.Pagination, required: true
  attr :path, :any, required: true, doc: "a function of the page number"
  attr :id, :string, default: "pagination"

  def pagination(assigns) do
    assigns = assign(assigns, :items, page_items(assigns.pagination))

    ~H"""
    <nav
      :if={@pagination.total_pages > 1}
      id={@id}
      aria-label="Pagination"
      class="mt-6 flex justify-center"
    >
      <div class="join">
        <.link
          patch={@path.(max(@pagination.page - 1, 1))}
          class={["join-item btn btn-sm", @pagination.page == 1 && "btn-disabled"]}
          aria-disabled={@pagination.page == 1 && "true"}
        >
          <.icon name="chevron-left" class="sm:hidden" /><span class="max-sm:sr-only">Previous</span>
        </.link>
        <%= for item <- @items do %>
          <span
            :if={item == :gap}
            class="join-item btn btn-sm pointer-events-none max-sm:hidden"
            aria-hidden="true"
            data-gap
          >
            …
          </span>
          <.link
            :if={item != :gap}
            patch={@path.(item)}
            class={["join-item btn btn-sm max-sm:hidden", item == @pagination.page && "btn-primary"]}
            aria-current={item == @pagination.page && "page"}
            data-page={item}
          >
            {item}
          </.link>
        <% end %>
        <span class="join-item btn btn-sm pointer-events-none tabular-nums sm:hidden">
          Page {@pagination.page} of {@pagination.total_pages}
        </span>
        <.link
          patch={@path.(min(@pagination.page + 1, @pagination.total_pages))}
          class={[
            "join-item btn btn-sm",
            @pagination.page == @pagination.total_pages && "btn-disabled"
          ]}
          aria-disabled={@pagination.page == @pagination.total_pages && "true"}
        >
          <span class="max-sm:sr-only">Next</span><.icon name="chevron-right" class="sm:hidden" />
        </.link>
      </div>
    </nav>
    """
  end

  defp page_items(%{total_pages: total}) when total <= 7, do: Enum.to_list(1..total//1)

  defp page_items(%{page: page, total_pages: total}) do
    [1, page - 1, page, page + 1, total]
    |> Enum.filter(&(&1 in 1..total))
    |> Enum.uniq()
    |> Enum.chunk_every(2, 1)
    |> Enum.flat_map(fn
      [a, b] when b - a > 1 -> [a, :gap]
      [a | _] -> [a]
    end)
  end

  @doc """
  Renders a book's rating as stars (★★★★☆) for the eye and as words
  ("Rated 4 out of 5") for screen readers; nothing without a rating.
  """
  attr :value, :integer, default: nil
  attr :class, :any, default: nil

  def rating(assigns) do
    ~H"""
    <span :if={is_integer(@value) and @value > 0} class={@class}>
      <span aria-hidden="true">{stars(@value)}</span>
      <span class="sr-only">Rated {@value} out of 5</span>
    </span>
    """
  end

  @doc """
  The admin URL of an image of the site (served by
  `FeatherWeb.ImageController`), optionally of a variant such as
  `"640.webp"`, or of the admin preview (`:preview`).
  """
  @spec image_path(
          Feather.Sites.Site.t(),
          Feather.Media.Image.t() | nil,
          String.t() | :preview | nil
        ) :: String.t() | nil
  def image_path(site, image, variant \\ nil)
  def image_path(_site, nil, _variant), do: nil

  def image_path(site, image, :preview),
    do: image_path(site, image, Variants.preview().filename)

  def image_path(site, image, nil),
    do: Blocks.image_url(site, image.public_id)

  def image_path(site, image, variant),
    do: Blocks.image_url(site, image.public_id) <> "?variant=#{variant}"

  @doc "Renders a rating as stars, e.g. ★★★★☆."
  @spec stars(integer() | nil) :: String.t()
  def stars(rating) when is_integer(rating) and rating > 0,
    do: String.duplicate("★", rating) <> String.duplicate("☆", 5 - rating)

  def stars(_rating), do: ""
end
