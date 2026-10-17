defmodule Feather.StaticSite.Theme do
  @moduledoc """
  What a theme of the static site implements (ADR 0015): its layout and
  page views, its stylesheet and its fonts. Themes are listed in
  `Feather.StaticSite.Themes`; block rendering, routes, Gettext, meta
  tags, feed, sitemap and image variants are shared.

  `use Feather.StaticSite.Theme` declares the behaviour and imports
  `Feather.StaticSite.ThemeHelpers`, `Phoenix.HTML.raw/1` and the static
  site's Gettext. Templates are EEx with `Phoenix.HTML.Engine` (output is
  escaped unless it is `{:safe, iodata}`) rather than HEEx, which would add
  the app's `phx-r` root tag attribute to the static pages.

  ## Views

  `Feather.StaticSite.Renderer` calls a view with the assigns of the page,
  then `c:layout/1` with the same assigns plus `inner_content`, the view's
  output. Every page gets:

    * `data` (`Feather.StaticSite.SiteData`), `site` (its mascots and
      portrait preloaded), `routes`, `ctx` (for `Feather.StaticSite.Blocks`),
      `social_links`
    * `page_title` (the visible heading), `meta_title` (the name in
      `<title>` and `og:title`; an untitled post's label where `page_title`
      is the site title), `document_title`, `page_emoji`, `is_home`,
      `noindex`, the meta tags (`description`, `canonical_url`, `og_type`,
      `og_image_url`; render them with `ThemeHelpers.head_meta/1`)
    * `header_image`, `title_mascot`, `published_at`, `masthead_image`,
      `rss_url`, `trail` (breadcrumb entries `%{title, emoji, url}`), all
      `nil` or `[]` unless the view sets them

  and each view its own:

    * `c:home/1` - `posts`, `current_page`, `total_pages`
    * `c:post/1` - `post`, `newer_post`, `older_post`
    * `c:page/1` - `page`
    * `c:project/1` - `project`
    * `c:not_found/1` - `projects_page` (nil without one)
  """

  alias Feather.StaticSite.Routes

  @type assigns :: map()

  @callback layout(assigns()) :: Phoenix.HTML.safe()
  @callback home(assigns()) :: Phoenix.HTML.safe()
  @callback post(assigns()) :: Phoenix.HTML.safe()
  @callback page(assigns()) :: Phoenix.HTML.safe()
  @callback project(assigns()) :: Phoenix.HTML.safe()
  @callback not_found(assigns()) :: Phoenix.HTML.safe()

  @doc "The stylesheet the layout inlines into every page."
  @callback css() :: String.t()

  @doc "The `@font-face` rules of the theme's fonts (see `ThemeHelpers.font_face/5`)."
  @callback font_faces(Routes.t()) :: Phoenix.HTML.safe()

  @doc """
  The files the export writes under `fonts/`, file name to content type,
  font licences included.
  """
  @callback fonts() :: %{String.t() => String.t()}

  @doc "The path of one of `c:fonts/0` in the app."
  @callback font_path(String.t()) :: Path.t()

  @doc """
  The site's image fields (of `Feather.Sites.Site.image_fields/0`) the
  theme renders; the export copies only their images.
  """
  @callback site_image_fields() :: [atom()]

  defmacro __using__(_opts) do
    quote do
      @behaviour Feather.StaticSite.Theme

      use Gettext, backend: Feather.StaticSite.Gettext

      require EEx

      import Phoenix.HTML, only: [raw: 1], warn: false
      import Feather.StaticSite.ThemeHelpers, warn: false
    end
  end
end
