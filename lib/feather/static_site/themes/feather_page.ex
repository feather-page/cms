defmodule Feather.StaticSite.Themes.FeatherPage do
  @moduledoc """
  The `feather` theme: a narrow column with a masthead on the home page,
  a breadcrumb elsewhere and the site's mascots, headings in Nunito, code
  in JetBrains Mono. Templates in `feather_page/*.html.eex`, stylesheet
  and fonts in `priv/static_site/themes/feather_page/`.
  """

  use Feather.StaticSite.Theme

  alias Feather.Content
  alias Feather.Media.Image
  alias Feather.Sites.Site
  alias Feather.StaticSite.{Blocks, Routes}
  alias Feather.StaticSite.Themes.FeatherPage.Hue

  @priv_dir Path.expand("../../../../priv/static_site/themes/feather_page", __DIR__)
  @css_path Path.join(@priv_dir, "theme.css")
  @external_resource @css_path
  @css File.read!(@css_path)

  @fonts %{
    "nunito-latin-700.woff2" => "font/woff2",
    "nunito-latin-800.woff2" => "font/woff2",
    "OFL.txt" => "text/plain"
  }

  @views ~w(layout home post page project not_found)a
  @partials ~w(masthead post_book_card books_list projects_list project_card tags)a

  for name <- @views ++ @partials do
    if name in @views, do: @impl(true)

    EEx.function_from_file(
      :def,
      name,
      Path.join([__DIR__, "feather_page", "#{name}.html.eex"]),
      [:assigns],
      engine: Phoenix.HTML.Engine,
      trim: true
    )
  end

  @impl true
  def css, do: @css

  @impl true
  def font_faces(%Routes{} = routes) do
    [
      font_face(routes, "Nunito", 700, ["Nunito Bold", "Nunito-Bold"], "nunito-latin-700.woff2"),
      font_face(
        routes,
        "Nunito",
        800,
        ["Nunito ExtraBold", "Nunito-ExtraBold"],
        "nunito-latin-800.woff2"
      ),
      jetbrains_mono_faces(routes)
    ]
  end

  # Nunito 700 and 800, Latin subset of @fontsource/nunito 5.2.7, SIL Open Font License.
  @impl true
  def fonts, do: Map.merge(@fonts, jetbrains_mono_fonts())

  @impl true
  def font_path(name),
    do: Application.app_dir(:feather, "priv/static_site/themes/feather_page/fonts/#{name}")

  # The text column: 35rem, or the viewport less two clamp(1rem, 4vw, 1.5rem) gutters.
  @impl true
  def content_image_sizes,
    do: "(min-width: 38rem) 35rem, (min-width: 25rem) 92vw, calc(100vw - 2rem)"

  @impl true
  def book_cover_sizes, do: "80px"

  # Columns of 560–608 px, small boxes at 1×, 2× and 3×; the inventory is on issue #453.
  @impl true
  def image_variants do
    %{
      content: [640, 960, 1280, 1600],
      homepage_header: [640, 960, 1280, 1600],
      header: [640, 960, 1280],
      project_header: [640, 960, 1280],
      thumbnail: [240, 480, 960, 1280],
      project_thumbnail: [128],
      book_cover: [180, 360, 540],
      projects_mascot: [160, 320, 480],
      post_end_mascot: [160, 320, 480],
      footer_mascot: [280, 560, 800]
    }
  end

  @impl true
  def site_image_fields, do: Site.mascot_fields()

  defp hue(site), do: Hue.for_emoji(site.emoji)

  defp rating(rating, class) do
    stars = rating |> max(0) |> min(5)

    {:safe,
     [
       ~s(<span class="),
       class,
       ~s(" role="img" aria-label="),
       rating_label(rating),
       ~s("><span aria-hidden="true">),
       String.duplicate("★", stars),
       String.duplicate("☆", 5 - stars),
       "</span></span>"
     ]}
  end

  defp seal(emoji),
    do: {:safe, [~s(<span class="seal" aria-hidden="true">), escape(emoji), "</span>"]}

  defp chip(href, emoji, title, current? \\ false) do
    {class, {:safe, seal}} =
      if present?(emoji), do: {"chip", seal(emoji)}, else: {"chip chip--plain", {:safe, []}}

    {:safe,
     [
       ~s(<a class="),
       class,
       ~s(" href="),
       escape(href),
       ~s("),
       if(current?, do: ~s( aria-current="page"), else: ""),
       ">",
       seal,
       escape(title),
       "</a>"
     ]}
  end

  defp variants(role), do: Map.fetch!(image_variants(), role)

  defp header_role(%{post: _post}), do: :header
  defp header_role(%{project: _project}), do: :project_header
  defp header_role(_assigns), do: :header

  # Mascots are characters, not content: decorative, so alt is empty.
  defp mascot(routes, %Image{} = image, role, class, sizes, opts \\ []) do
    {:safe,
     [
       ~s(<img class="),
       class,
       ~s("),
       routes |> image_sources(image, variants(role), sizes) |> elem(1),
       image |> dimensions() |> elem(1),
       if(Keyword.get(opts, :lazy, true), do: ~s( loading="lazy"), else: ""),
       ~s( alt="">)
     ]}
  end

  defp not_found_mascot(%{post_end_mascot_image: %Image{} = image}), do: {image, :post_end_mascot}
  defp not_found_mascot(%{projects_mascot_image: %Image{} = image}), do: {image, :projects_mascot}
  defp not_found_mascot(_site), do: nil

  defp not_found_mascot_image(routes, site) do
    {image, role} = not_found_mascot(site)
    mascot(routes, image, role, "not-found-mascot", nav_mascot_sizes(image), lazy: false)
  end

  # A box of 9rem × 8.5rem, contained.
  defp nav_mascot_sizes(image), do: "#{contained_width(image, 144, 136)}px"

  # Up to clamp(12rem, 9rem + 10vw, 16.5rem) wide and 5.5rem high, contained.
  defp footer_mascot_sizes(image) do
    case contained_width(image, 264, 88) do
      width when width <= 192 -> "#{width}px"
      _wider -> "(min-width: 75rem) 16.5rem, (min-width: 30rem) calc(9rem + 10vw), 12rem"
    end
  end
end
